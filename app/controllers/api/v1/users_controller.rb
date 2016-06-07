module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      def show
        render json: current_user
      end

      def toggle_active
        current_user.toggle_active!
        render json: { active: current_user.active? }
      end

      private

      def vote_params
        params.require(:vote).permit(:final, :overall, :reason, *Vote::METRICS)
      end

      def company
        @company ||= Company.find(params[:company_id])
      end
    end
  end
end