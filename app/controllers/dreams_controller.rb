class DreamsController < ApplicationController
  def update
    dream = current_user.dreams.find(params[:id])
    if dream.update(params.require(:dream).permit(:title))
      redirect_to life_points_path, notice: t("life_points.dream_updated")
    else
      redirect_to life_points_path, alert: dream.errors.full_messages.to_sentence
    end
  end
end
