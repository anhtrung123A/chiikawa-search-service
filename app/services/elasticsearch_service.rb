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
    category_slug: nil,
    character_slug: nil,
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

    # Name fuzzy search
    must_clauses << { match: { name: { query: name, fuzziness: "AUTO" } } } if name.present?

    # Category filter (nested)
    if category_slug.present?
      must_clauses << {
        nested: {
          path: "categories",
          query: { term: { "categories.slug": category_slug } }
        }
      }
    end

    # Character filter (nested)
    if character_slug.present?
      must_clauses << {
        nested: {
          path: "characters",
          query: { term: { "characters.slug": character_slug } }
        }
      }
    end

    # Price range filter
    if min_price.present? || max_price.present?
      range_query = {}
      range_query[:gte] = min_price if min_price.present?
      range_query[:lte] = max_price if max_price.present?
      must_clauses << { range: { price: range_query } }
    end

    # Status filter
    must_clauses << { term: { status: status } } if status.present?

    # Build sort
    sort_clause = []
    if sort_by.present?
      field = case sort_by.to_sym
              when :name then "name.keyword"       # keyword để sort A-Z / Z-A
              when :price then "price"
              when :created_at then "created_at"
              else nil
              end
      sort_clause << { field => { order: sort_order } } if field
    end

    # Elasticsearch query with nested aggregations
    response = ELASTICSEARCH_CLIENT.search(
      index: INDEX_NAME,
      body: {
        from: from,
        size: limit,
        query: {
          bool: { must: must_clauses }
        },
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

    {
      results: response["hits"]["hits"].map { |hit| hit["_source"] },
      total: response["hits"]["total"]["value"],
      page: page,
      limit: limit,
      characters_count: response.dig("aggregations", "characters_count", "by_slug", "buckets")&.map { |b| { slug: b["key"], count: b["doc_count"] } } || [],
      categories_count: response.dig("aggregations", "categories_count", "by_slug", "buckets")&.map { |b| { slug: b["key"], count: b["doc_count"] } } || [],
      status_count: response.dig("aggregations", "status_count", "buckets")&.map { |b| { status: b["key"], count: b["doc_count"] } } || []
    }
  end
end