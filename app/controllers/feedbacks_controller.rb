class FeedbacksController < ApplicationController
  def new
  end

  # Kept for older clients / bookmarks; direct users to contact options.
  def create
    redirect_to new_feedback_path, notice: "Message me on WhatsApp or email — pick a contact below."
  end
end
