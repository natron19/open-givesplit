class NeedsController < ApplicationController
  before_action :set_need, only: %i[show edit update destroy]

  def index
    @needs = current_user.needs.includes(latest_parts_plan: :parts).order(created_at: :desc)
  end

  def show
    @parts_plans = @need.parts_plans.order(created_at: :desc)
  end

  def new
    @need = current_user.needs.build(kinds: Need::KINDS, currency: "USD")
  end

  def create
    @need = current_user.needs.build(need_params)
    if @need.save
      redirect_to @need
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @need.update(need_params)
      redirect_to @need
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @need.destroy
    redirect_to needs_path
  end

  private

  def set_need
    @need = current_user.needs.find(params[:id])
  end

  def need_params
    params.require(:need).permit(:need_text, :currency, :community_context, :rough_budget, kinds: [])
  end
end
