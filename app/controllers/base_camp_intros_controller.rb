# frozen_string_literal: true

class BaseCampIntrosController < ApplicationController
  def update
    current_user.mark_base_camp_intro_seen!
    head :no_content
  end
end
