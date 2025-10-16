# - todo
#       + Boost search results by some metrics (views, sales)
class ElasticsearchService
  INDEX_NAME = "products"

  def self.create_index
    ELASTICSEARCH_CLIENT.indices.create(
      index: INDEX_NAME,
      body: {
        settings: {
          analysis: {
            filter: {
              autocomplete_filter: {
                type: "edge_ngram",
                min_gram: 2,
                max_gram: 20
              }
            },
            analyzer: {
              autocomplete: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "autocomplete_filter"]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: "keyword" },
            price: { type: "integer" },
            name: { type: "text", analyzer: "autocomplete", search_analyzer: "standard" },
            images: { type: "keyword" },
            categories: {
              type: "nested",
              properties: {
                name: { type: "text", analyzer: "standard" },
                slug: { type: "keyword" }
              }
            },
            characters: {
              type: "nested",
              properties: {
                name: { type: "text", analyzer: "standard" },
                slug: { type: "keyword" }
              }
            },
            status: { type: "keyword" },
            created_at: { type: "date" }
          }
        }
      }
    )
  rescue Elastic::Transport::Transport::Errors::BadRequest => e
    puts "Index already exists: #{e.message}"
  end

  def self.index(data)
    normalized_data = data.dup
    normalized_data[:name] = data[:name].is_a?(Array) ? data[:name].first : data[:name]
    normalized_data[:status] = data[:status].is_a?(Array) ? data[:status].first : data[:status]
    normalized_data[:created_at] = data[:created_at].is_a?(Array) ? data[:created_at].first : data[:created_at]
    normalized_data[:price] = data[:price].is_a?(Array) ? data[:price].first : data[:price]

    ELASTICSEARCH_CLIENT.index(
      index: INDEX_NAME,
      id: data[:id].is_a?(Array) ? data[:id].first : data[:id],
      body: normalized_data
    )
  end

  def self.search_products(
    name: nil,
    category_slugs: [],
    character_slugs: [],
    min_price: nil,
    max_price: nil,
    status: nil,
    page: 1,
    limit: 10,
    sort_by: nil,
    sort_order: "asc"
  )
    from = (page - 1) * limit
    must_clauses = []

    # --- Name fuzzy search ---
    must_clauses << { match: { name: { query: name, fuzziness: "AUTO" } } } if name.present?

    # --- Category filter (nested, multiple) ---
    if category_slugs.present?
      must_clauses << {
        nested: {
          path: "categories",
          query: {
            bool: {
              should: category_slugs.map { |slug| { term: { "categories.slug": slug } } },
              minimum_should_match: 1
            }
          }
        }
      }
    end

    # --- Character filter (nested, multiple) ---
    if character_slugs.present?
      must_clauses << {
        nested: {
          path: "characters",
          query: {
            bool: {
              should: character_slugs.map { |slug| { term: { "characters.slug": slug } } },
              minimum_should_match: 1
            }
          }
        }
      }
    end

    # --- Price range filter ---
    if min_price.present? || max_price.present?
      range_query = {}
      range_query[:gte] = min_price if min_price.present?
      range_query[:lte] = max_price if max_price.present?
      must_clauses << { range: { price: range_query } }
    end

    # --- Status filter ---
    must_clauses << { term: { status: status } } if status.present?

    # --- Sort ---
    sort_clause = []
    if sort_by.present?
      field = case sort_by.to_sym
              when :name then "name.keyword"
              when :price then "price"
              when :created_at then "created_at"
              else nil
              end
      sort_clause << { field => { order: sort_order } } if field
    end

    # --- 1️⃣ Get all unique slugs across the entire index ---
    all_keys = ELASTICSEARCH_CLIENT.search(
      index: INDEX_NAME,
      body: {
        size: 0,
        aggs: {
          all_characters: {
            nested: { path: "characters" },
            aggs: {
              by_slug: { terms: { field: "characters.slug", size: 10_000 } }
            }
          },
          all_categories: {
            nested: { path: "categories" },
            aggs: {
              by_slug: { terms: { field: "categories.slug", size: 10_000 } }
            }
          },
          all_statuses: {
            terms: { field: "status", size: 100 }
          }
        }
      }
    )

    all_characters = all_keys.dig("aggregations", "all_characters", "by_slug", "buckets")&.map { |b| b["key"] } || []
    all_categories = all_keys.dig("aggregations", "all_categories", "by_slug", "buckets")&.map { |b| b["key"] } || []
    all_statuses   = all_keys.dig("aggregations", "all_statuses", "buckets")&.map { |b| b["key"] } || []

    # --- 2️⃣ Run filtered query ---
    response = ELASTICSEARCH_CLIENT.search(
      index: INDEX_NAME,
      body: {
        from: from,
        size: limit,
        query: { bool: { must: must_clauses } },
        sort: sort_clause,
        aggs: {
          characters_count: {
            nested: { path: "characters" },
            aggs: {
              by_slug: { terms: { field: "characters.slug", size: 100 } }
            }
          },
          categories_count: {
            nested: { path: "categories" },
            aggs: {
              by_slug: { terms: { field: "categories.slug", size: 100 } }
            }
          },
          status_count: {
            terms: { field: "status", size: 10 }
          }
        }
      }
    )

    # --- 3️⃣ Merge counts: keep all keys, fill missing with 0 ---
    chars_raw = response.dig("aggregations", "characters_count", "by_slug", "buckets") || []
    cats_raw  = response.dig("aggregations", "categories_count", "by_slug", "buckets") || []
    stat_raw  = response.dig("aggregations", "status_count", "buckets") || []

    char_map = chars_raw.to_h { |b| [b["key"], b["doc_count"]] }
    cat_map  = cats_raw.to_h  { |b| [b["key"], b["doc_count"]] }
    stat_map = stat_raw.to_h  { |b| [b["key"], b["doc_count"]] }

    characters_count = all_characters.map { |slug| { slug: slug, count: char_map[slug] || 0 } }
    categories_count = all_categories.map { |slug| { slug: slug, count: cat_map[slug] || 0 } }
    status_count     = all_statuses.map   { |status| { status: status, count: stat_map[status] || 0 } }

    # --- Final result ---
    {
      results: response["hits"]["hits"].map { |hit| hit["_source"] },
      total: response["hits"]["total"]["value"],
      page: page,
      limit: limit,
      characters_count: characters_count,
      categories_count: categories_count,
      status_count: status_count
    }
  end

  
  def self.delete(product_id)
    ELASTICSEARCH_CLIENT.delete(index: INDEX_NAME, id: product_id)
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    puts "Document #{product_id} not found, skip delete"
  end
end