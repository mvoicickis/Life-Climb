class ShipBuilding
  def initialize(building:, title: nil, value_summary: nil)
    @building = building
    @user = building.user
    @title = title.presence || building.title
    @value_summary = value_summary
  end

  def call
    return if @building.status == "shipped"

    product = nil
    ActiveRecord::Base.transaction do
      @building.update!(status: "shipped", shipped_at: Time.current)
      @building.step.update!(status: "done") if @building.step.buildings.active.none?

      product = @user.finished_products.create!(
        building: @building,
        goal: @building.goal,
        title: @title,
        value_summary: @value_summary,
        shipped_on: Date.current
      )

      award = LifePointsAward.new(@user)
      award.for_building_ship!(@building)
      award.for_finished_product!(product)

      if @user.focus_building_id == @building.id
        next_building = @user.buildings.active.order(:id).first
        @user.update!(focus_building: next_building)
      end
    end

    product
  end
end
