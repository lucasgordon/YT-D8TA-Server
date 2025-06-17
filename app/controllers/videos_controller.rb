class VideosController < ApplicationController
  def index
    @video = Video.first
  end
end
