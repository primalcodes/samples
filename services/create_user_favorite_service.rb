module Services
  class FavoriteError < StandardError; end

  # Service to encapsulate creating a user favorite record of a given recipe.
  class CreateUserFavoriteService
    def initialize(params = {})
      %i[recipe_id user].each do |arg|
        raise ArgumentError, "Missing argument: #{arg}" if params[arg].nil?
      end

      resp = params.with_indifferent_access
      @recipe_id = resp[:recipe_id]
      @user = params[:user]
    end

    def call
      user_favorite = create_user_favorite
      OpenStruct.new({ success?: true, payload: { favorite_id: user_favorite.id } })
    rescue FavoriteError => e
      OpenStruct.new({ success?: false, message: e.message })
    end

    private

    def create_user_favorite
      recipe = Recipe.find_by(id: @recipe_id)
      raise FavoriteError, 'Recipe not found' unless recipe

      user_favorite = UserFavorite.find_or_initialize_by(
        recipe: recipe,
        user: @user
      )
      raise FavoriteError, 'User favorite already exists.' if user_favorite.persisted?

      return user_favorite if user_favorite.save

      raise FavoriteError, user_favorite.errors.full_messages.to_sentence
    end
  end
end
