defmodule Mix.Tasks.TakeOneTimeActionsAsPerWhatsappResponse do
  use Mix.Task

  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Accounts.Owner
  require Logger

  import Ecto.Query

  def run(_) do
    Mix.Task.run("app.start", [])

    File.stream!("#{File.cwd!()}/priv/data/owner_post_whatsapp_replies.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&take_actions_on_post/1)
  end

  def get_owner_non_expired_posts_query(post_class, owner_phone_number) do
    current_time =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()
      |> Timex.shift(days: -2)
      |> DateTime.to_unix()

    post_class
    |> join(:inner, [r], o in Owner, on: o.id == r.assigned_owner_id)
    |> where([r, o], r.uploader_type == ^"owner" and r.archived == false and o.phone_number == ^owner_phone_number)
    |> where([r, o], ^current_time >= fragment("ROUND(extract(epoch from ?))", r.expires_in))
  end

  def take_actions_on_post({:error, data}) do
    Logger.info("Error: #{data}")
    nil
  end

  def take_actions_on_post({:ok, data}) do
    owner_phone_number = data |> Enum.at(1)
    post_type = data |> Enum.at(6)
    action = data |> Enum.at(5)
    content_type = data |> Enum.at(3)

    if content_type == "button" do
      cond do
        post_type == "RESALE" and action == "DEACTIVATE" ->
          query = get_owner_non_expired_posts_query(ResalePropertyPost, owner_phone_number)

          number_of_owner_properties =
            query
            |> Repo.all()
            |> length()

          if number_of_owner_properties == 1 do
            post = query |> Repo.one()

            Posts.handle_whatsapp_button_webhook(
              %{
                "post_type" => "resale",
                "post_uuid" => post.uuid,
                "action" => "deactivate"
              },
              owner_phone_number
            )

            Logger.info("Post: #{post_type}, Action: #{action}, Post_Uuid: #{post.uuid}, Owner Phone Number: #{owner_phone_number}")
          else
            Logger.info(
              "Post: #{post_type}, Action: Could not update or refresh, Owner Phone Number: #{owner_phone_number}, Number of Owner Properties: #{number_of_owner_properties}"
            )
          end

        post_type == "RENT" and action == "DEACTIVATE" ->
          query = get_owner_non_expired_posts_query(RentalPropertyPost, owner_phone_number)

          number_of_owner_properties =
            query
            |> Repo.all()
            |> length()

          if number_of_owner_properties == 1 do
            post = query |> Repo.one()

            Posts.handle_whatsapp_button_webhook(
              %{
                "post_type" => "rent",
                "post_uuid" => post.uuid,
                "action" => "deactivate"
              },
              owner_phone_number
            )

            Logger.info("Post: #{post_type}, Action: #{action}, Post_Uuid: #{post.uuid}, Owner Phone Number: #{owner_phone_number}")
          else
            Logger.info(
              "Post: #{post_type}, Action: Could not update or refresh, Owner Phone Number: #{owner_phone_number}, Number of Owner Properties: #{number_of_owner_properties}"
            )
          end

        post_type == "NA" and action == "REFRESH" ->
          rental_query = get_owner_non_expired_posts_query(RentalPropertyPost, owner_phone_number)

          number_of_rental_owner_properties =
            rental_query
            |> Repo.all()
            |> length()

          resale_query = get_owner_non_expired_posts_query(ResalePropertyPost, owner_phone_number)

          number_of_resale_owner_properties =
            resale_query
            |> Repo.all()
            |> length()

          cond do
            number_of_rental_owner_properties == 1 and number_of_resale_owner_properties == 0 ->
              post = rental_query |> Repo.one()

              Posts.handle_whatsapp_button_webhook(
                %{
                  "post_type" => "rent",
                  "post_uuid" => post.uuid,
                  "action" => "refresh"
                },
                owner_phone_number
              )

              post_type = "RENT"

              Logger.info("Post: #{post_type}, Action: #{action}, Post_Uuid: #{post.uuid}, Owner Phone Number: #{owner_phone_number}")

            number_of_resale_owner_properties == 1 and number_of_rental_owner_properties == 0 ->
              post = resale_query |> Repo.one()

              Posts.handle_whatsapp_button_webhook(
                %{
                  "post_type" => "resale",
                  "post_uuid" => post.uuid,
                  "action" => "refresh"
                },
                owner_phone_number
              )

              post_type = "RESALE"

              Logger.info("Post: #{post_type}, Action: #{action}, Post_Uuid: #{post.uuid}, Owner Phone Number: #{owner_phone_number}")

            true ->
              Logger.info(
                "Owner Phone Number: #{owner_phone_number}, Action: Could not update or refresh, Number of rent properties: #{number_of_rental_owner_properties}, Number of resale properties: #{number_of_resale_owner_properties}"
              )
          end

        true ->
          Logger.info("Invalid row")
      end
    end
  end
end
