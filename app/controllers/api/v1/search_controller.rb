class Api::V1::SearchController < ApplicationController
  def search
    results = ElasticsearchService.search_products(
      name: search_params[:name],
      category_slug: search_params[:category_slug],
      character_slug: search_params[:character_slug],
      min_price: search_params[:min_price]&.to_i,
      max_price: search_params[:max_price]&.to_i,
      status: search_params[:status],
      page: search_params[:page]&.to_i || 1,
      limit: search_params[:limit]&.to_i || 24,
      sort_order: search_params[:sort_order],
      sort_by: search_params[:sort_by]
    )

    render json: results
  rescue => e
    render json: { error: e.message }, status: 500
  end

  private

  def search_params
    params.permit(
      :name,
      :category_slug,
      :character_slug,
      :min_price,
      :max_price,
      :status,
      :page,
      :limit,
      :sort_by,
      :sort_order
    )
  end
end
