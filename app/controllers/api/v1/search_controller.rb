class Api::V1::SearchController< ApplicationController
  def search
    results = ElasticsearchService.search_products(
      name: params[:name],
      category_slug: params[:category_slug],
      character_slug: params[:character_slug],
      min_price: params[:min_price]&.to_i,
      max_price: params[:max_price]&.to_i,
      status: params[:status],
      page: params[:page]&.to_i || 1,
      limit: params[:limit]&.to_i || 10
    )
    render json: results
  rescue => e
    render json: { error: e.message }, status: 500
  end
end
