class CommentsController < ApplicationController
  before_action :set_comment, only: %i[ destroy ]

  # GET /posts/1/comments/new
  def new
    @post = Post.find(params[:post_id])
    @comment = Comment.new(post_id: params[:post_id])
  end

  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.create(comment_params)

    redirect_to @post
  end

  # DELETE /posts/1/comments/1 or /posts/1/comments/1.json
  def destroy
    @comment.destroy

    respond_to do |format|
      format.html { redirect_to comments_url, notice: "Comment was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_comment
      @comment = Comment.find(params[:id], post_id: params[:post_id])
    end

    # Only allow a list of trusted parameters through.
    def comment_params
      params.require(:comment).permit(:content)
    end
end
