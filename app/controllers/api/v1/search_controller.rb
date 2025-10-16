class Api::V1::SearchController < ApplicationController
  def search
    results = ElasticsearchService.search_products(
      name: search_params[:name],
      category_slugs: search_params[:category_slug] || [],
      character_slugs: search_params[:character_slug] || [],
      min_price: search_params[:min_price]&.to_i,
      max_price: search_params[:max_price]&.to_i,
      status: search_params[:status],
      page: (search_params[:page] || 1).to_i,
      limit: (search_params[:limit] || 24).to_i,
      sort_by: search_params[:sort_by],
      sort_order: search_params[:sort_order]
    )

    render json: results
  rescue => e
    Rails.logger.error("Search error: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def search_params
    params.permit(
      :name,
      :min_price,
      :max_price,
      :status,
      :page,
      :limit,
      :sort_by,
      :sort_order,
      category_slug: [],
      character_slug: []
    )
  end
end
