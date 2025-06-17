class VideosController < ApplicationController
  def index
    @video = Video.first
    render :index
  end
end
