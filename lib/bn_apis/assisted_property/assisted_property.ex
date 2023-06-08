defmodule BnApis.AssistedProperty do
  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.AssistedProperty.Schema.{AssistedPropertyPostAgreement, AssistedPropertyPostAgreementLog}
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Documents.Document
  alias BnApis.Places.City
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.Owner
  alias BnApis.Buildings.Building
  alias BnApis.Digio.API, as: DigioApi
  alias BnApis.Digio.DigioDocs
  alias BnApis.DigioDocs.Schema.DigioDoc
  alias BnApis.Helpers.Utils
  alias BnApis.Helpers.ApplicationHelper

  @assigned "assigned"
  @failed "failed"
  @in_progress "in_progress"
  @in_review "in_review"
  @assisted "assisted"
  @deal_done "deal_done"
  @commission_collected "commission_collected"
  @expired "expired"

  @doc_types_supported ["property_photo", "payment_proof", "agreement", "property_kyc", "property_index"]
  @property_photo_doc_type "property_photo"

  @super_employee_role_id EmployeeRole.super().id

  @status_change_permission_role_mapping %{
    EmployeeRole.assisted_manager().id => %{
      @assigned => [@in_progress, @failed],
      @in_progress => [@in_review, @failed],
      @failed => [@in_progress],
      @assisted => [@deal_done]
    },
    EmployeeRole.assisted_admin().id => %{
      @in_review => [@assisted, @in_progress],
      @deal_done => [@commission_collected],
      @failed => [@in_progress]
    }
  }

  def property_photo_doc_type(), do: @property_photo_doc_type
  def assisted(), do: @assisted

  def get_assisted_property_by(params, preload \\ []), do: AssistedPropertyPostAgreement |> Repo.get_by(params) |> Repo.preload(preload)

  def list_assisted_property_by(params, preload \\ []) do
    where = for({key, val} <- params, into: %{}, do: {String.to_atom(key), val}) |> Map.to_list()
    assisted_properties = from(AssistedPropertyPostAgreement, where: ^where) |> Repo.all() |> Repo.preload(preload)
    {:ok, assisted_properties}
  end

  @spec create_assisted_property(:resale, atom | %{:building_id => any, optional(any) => any}) :: {:ok, any}
  def create_assisted_property(:resale, params = %{:building_id => _building_id}) do
    posts =
      Repo.all(
        from(r in ResalePropertyPost,
          left_join: app in AssistedPropertyPostAgreement,
          on: r.latest_assisted_property_post_agreement_id == app.id,
          where:
            (is_nil(app.id) or app.status == ^"expired") and
              (r.building_id == ^params.building_id and r.archived == false and r.uploader_type == ^"owner")
        )
      )

    # Need to check if any active assisgned post agreement exist before creating any new
    Repo.transaction(fn ->
      try do
        # Need to check if any active assisgned post agreement exist before creating any new
        {_, post_agreements} =
          Repo.insert_all(
            AssistedPropertyPostAgreement,
            Enum.map(posts, fn post ->
              Map.merge(params, %{
                resale_property_post_id: post.id,
                inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              })
            end),
            returning: true
          )

        current_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Enum.each(post_agreements, fn post_agreement ->
          params = %{
            edited_by_employees_credentials_id: post_agreement.updated_by_id,
            latest_assisted_property_post_agreement_id: post_agreement.id,
            updation_time: current_time,
            last_edited_at: current_time
          }

          update_post_record(post_agreement.resale_property_post_id, params)
        end)

        {_, _} =
          Repo.insert_all(
            AssistedPropertyPostAgreementLog,
            Enum.map(post_agreements, fn post_agreement ->
              %{
                status: post_agreement.status,
                notes: post_agreement.notes,
                agreement_id: post_agreement.id,
                updated_by_id: post_agreement.updated_by_id,
                inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              }
            end)
          )

        params.building_id
      rescue
        _err ->
          Repo.rollback("Unable to create assisted post")
      end
    end)
  end

  def create_assisted_property(:resale, _params), do: {:error, "Building missing for this property"}

  def update_assisted_properties(assisted_property_post_agreement_uuid, employee_role_in, user_id, params) do
    case Repo.get_by(AssistedPropertyPostAgreement, uuid: assisted_property_post_agreement_uuid) do
      nil ->
        {:error, "Assisted property not found"}

      assisted_post_agreement ->
        status = params["status"]
        {is_valid, msg} = validate_status_change(assisted_post_agreement, status, employee_role_in)
        current_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        post = Repo.get_by(ResalePropertyPost, id: assisted_post_agreement.resale_property_post_id)

        if is_valid do
          params = filter_update_param(params, employee_role_in)

          {post_params, params} =
            case status do
              # Update latest post agreement in post table
              @assisted ->
                # 4 months of Assisted
                validity_in_days = 120
                current_end_in_epoch = Time.get_end_time_in_unix(validity_in_days)
                current_end = Time.epoch_to_naive(current_end_in_epoch * 1000)
                current_time_in_epoch = current_time |> Time.naive_to_epoch_in_sec()
                expires_in = if not is_nil(post.expires_in), do: Time.get_max_naive_datetime([post.expires_in, current_end]), else: current_end

                {%{
                   is_assisted: true,
                   notes: "Guaranteed Brokerage & Instant Visit Support",
                   edited_by_employees_credentials_id: user_id,
                   updation_time: current_time,
                   last_edited_at: current_time,
                   expires_in: expires_in
                 },
                 Map.merge(params, %{
                   "current_start" => current_time_in_epoch,
                   "payment_date" => current_time_in_epoch,
                   "current_end" => current_end_in_epoch
                 })}

              # ARCHIVE POST HERE and make is_assisted false
              @deal_done ->
                {%{
                   archived: true,
                   is_assisted: false,
                   edited_by_employees_credentials_id: user_id,
                   archived_by_employees_credentials_id: user_id,
                   last_archived_at: current_time,
                   updation_time: current_time,
                   last_edited_at: current_time
                 }, params}

              @in_progress ->
                {%{}, Map.merge(params, %{"owner_agreement_status" => "not_created"})}

              # Update is_active false
              @failed ->
                {%{latest_assisted_property_post_agreement_id: nil}, Map.merge(params, %{"is_active" => false})}

              # Update is_active false
              @expired ->
                {%{}, Map.merge(params, %{"is_active" => false})}

              _ ->
                {%{}, params}
            end

          Repo.transaction(fn ->
            try do
              update_post_record(assisted_post_agreement.resale_property_post_id, post_params)
              update_assisted_record(assisted_post_agreement, params)
              assisted_post_agreement
            rescue
              _err ->
                Repo.rollback("Unable to update post or assisted post")
            end
          end)
        else
          {:error, msg}
        end
    end
  end

  defp filter_update_param(params, employee_role_in) do
    cond do
      employee_role_in == EmployeeRole.assisted_manager().id ->
        Map.take(params, ["status", "notes", "updated_by_id", "validity_in_days"])

      employee_role_in == EmployeeRole.assisted_admin().id ->
        Map.take(params, ["status", "notes", "assisted_by_id", "updated_by_id", "current_start", "current_end", "payment_date"])

      employee_role_in == EmployeeRole.super().id ->
        params

      true ->
        %{}
    end
  end

  defp validate_status_change(_assisted_post_agreement, status, _employee_role_id) when is_nil(status),
    do: {true, "No status to be updated"}

  defp validate_status_change(_assisted_post_agreement, _status, employee_role_id) when employee_role_id == @super_employee_role_id,
    do: {true, "Change is valid"}

  defp validate_status_change(assisted_post_agreement, to_status_identifier, employee_role_id) do
    from_status_identifier = "#{assisted_post_agreement.status}"

    if not is_nil(@status_change_permission_role_mapping[employee_role_id]) and
         not is_nil(@status_change_permission_role_mapping[employee_role_id][from_status_identifier]) and
         to_status_identifier in @status_change_permission_role_mapping[employee_role_id][from_status_identifier] do
      {true, "Status change is valid"}
    else
      {false, "Current Employee is not authorized to change status from #{from_status_identifier} to #{to_status_identifier}"}
    end
  end

  def update_post_record(post_id, params) do
    case Repo.get_by(ResalePropertyPost, id: post_id) do
      nil ->
        {:error, "Post not found"}

      post ->
        ResalePropertyPost.changeset(post, params) |> Repo.update()
    end
  end

  def update_assisted_record(assisted_post_agreement, params) do
    assisted_post_agreement
    |> AssistedPropertyPostAgreement.changeset(params)
    |> Repo.update()
  end

  def fetch_assisted_properties(post_type, params) do
    {_query, content_query, _page, size} = assisted_properties_filter_query(post_type, params)

    assisted_properties =
      content_query
      |> preload([
        :building,
        :assisted_by,
        :assigned_by,
        :updated_by,
        :resale_property_post,
        resale_property_post: :configuration_type,
        resale_property_post: :assigned_owner,
        building: :polygon
      ])
      |> Repo.all()
      |> Enum.map(&create_assisted_property_map/1)

    has_more_assisted_properties? = length(assisted_properties) > size
    {:ok, assisted_properties, has_more_assisted_properties?}
  end

  def upload_document(params, user_id) do
    documents = params["documents"]

    if is_list(documents) and length(documents) > 0 do
      assisted_property_uuid = params["assisted_property_post_agreement_uuid"]

      case Repo.get_by(AssistedPropertyPostAgreement, uuid: assisted_property_uuid) do
        nil ->
          {:error, "assisted property post agreement not found"}

        assisted_property_post_agreement ->
          documents =
            documents
            |> Enum.map(fn doc ->
              doc
              |> Map.merge(%{
                "entity_id" => assisted_property_post_agreement.id,
                "entity_type" => AssistedPropertyPostAgreement.schema_name()
              })
            end)

          Document.upload_document(documents, user_id, AssistedPropertyPostAgreement.schema_name(), "employee")
          {uploaded_docs, _number_of_documents} = Document.get_document(assisted_property_post_agreement.id, AssistedPropertyPostAgreement.schema_name(), true)
          {:ok, %{message: "documents uploaded succesfully", uploaded_docs: uploaded_docs, status: true}}
      end
    else
      {:ok, %{message: "No documents to be uploaded", uploaded_docs: [], status: false}}
    end
  end

  def remove_document(params) do
    case Repo.get_by(AssistedPropertyPostAgreement, uuid: params["assisted_property_post_agreement_uuid"]) do
      nil ->
        {:error, "assisted property post agreement not found"}

      assisted_property_post_agreement ->
        doc_id = if is_binary(params["doc_id"]), do: String.to_integer(params["doc_id"]), else: params["doc_id"]
        Document.remove_document(doc_id, assisted_property_post_agreement.id, AssistedPropertyPostAgreement.schema_name())
    end
  end

  def fetch_agreement(
        assisted_property_post_agreement_uuid,
        owner_aadhar_number,
        owner_pan_number,
        owner_current_address,
        owner_email_id,
        property_address,
        employee_name,
        employee_phone_number
      ) do
    with %AssistedPropertyPostAgreement{} = assisted_property_post_agreement <-
           AssistedPropertyPostAgreement
           |> where(uuid: ^assisted_property_post_agreement_uuid)
           |> preload([:resale_property_post, resale_property_post: [:assigned_owner]])
           |> Repo.one(),
         %Owner{phone_number: phone_number, name: name} = owner <- assisted_property_post_agreement.resale_property_post.assigned_owner,
         false <- is_nil(phone_number) or is_nil(name) do
      with %DigioDoc{} = digio_doc <-
             DigioDocs.get_doc_details_by(%{entity_type: AssistedPropertyPostAgreement.schema_name(), entity_id: assisted_property_post_agreement.id, is_active: true}) do
        {:ok, digio_doc.esign_link_map}
      else
        nil ->
          assisted_property_post_agreement =
            Repo.preload(assisted_property_post_agreement,
              resale_property_post: [:building, :configuration_type, :floor_type, :assigned_owner]
            )

          signer_details = fetch_and_update_signer_info(owner, %{email: owner_email_id})

          # Generate file using template
          agreement_details =
            fetch_agreement_details(assisted_property_post_agreement.resale_property_post, owner_aadhar_number, owner_pan_number, owner_current_address, property_address)

          agreement_details = append_date_params(agreement_details)
          agreement_template_params = DigioApi.fetch_template_params_to_generate_documents("assisted_owner_agreement", agreement_details)
          file_path = DigioApi.generate_document_from_template([agreement_template_params])

          # Save the document on AWS S3 bucket, and save the url in assisted table
          sign_coordinates = DigioApi.generate_sign_coordinates_for_template("assisted_owner_agreement", owner.phone_number)

          with digio_doc <-
                 DigioApi.upload_pdf_for_digio(file_path, [signer_details], sign_coordinates, %{
                   "entity_id" => assisted_property_post_agreement.id,
                   "entity_type" => AssistedPropertyPostAgreement.schema_name()
                 }),
               false <- is_nil(digio_doc) do
            update_assisted_record(assisted_property_post_agreement, %{owner_agreement_status: :pending})
            send_esign_mssg_to_owner(digio_doc.esign_link_map, employee_name, employee_phone_number)

            {:ok, digio_doc.esign_link_map}
          else
            _ ->
              {:error, "Failed to generate agreement"}
          end
      end
    else
      nil -> {:error, :not_found}
      true -> {:error, "Owner phone number or name not found"}
    end
  end

  def fetch_and_update_signer_info(owner, params) do
    Owner.update(owner, params)
    get_owner_signer_details(owner)
  end

  def append_date_params(params) do
    {{year, month, date}, _time} = :calendar.local_time()

    Map.merge(params, %{
      date_of_agreement_creation: date,
      month_of_agreement_creation: Utils.get_month_name_by_month_number(month),
      year_of_agreement_creation: year
    })
  end

  def get_owner_signer_details(owner_details) do
    %{
      identifier: owner_details.phone_number,
      name: owner_details.name,
      reason: "Owner Agreement"
    }
  end

  def fetch_agreement_details(post, owner_aadhar_number, owner_pan_number, owner_current_address, property_address) do
    %{
      owner_aadhar_number: owner_aadhar_number,
      owner_pan_number: owner_pan_number,
      owner_current_address: owner_current_address,
      owner_name: post.assigned_owner.name,
      full_address: property_address,
      configuration_name: post.configuration_type.name,
      price: post.price,
      carpet_area: post.carpet_area,
      parking: post.parking,
      floor_name: post.floor_type.name,
      term: 4,
      facilitation_fee: 2,
      expiry_tenure: 4
    }
  end

  def send_esign_mssg_to_owner(esign_link_map, employee_name, employee_phone_number) do
    Enum.each(esign_link_map, fn esign_details ->
      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
        esign_details.identifier,
        "onwer_agreement",
        [esign_details.signer_name, esign_details.esign_doc_url, employee_name, employee_phone_number]
      ])
    end)
  end

  def validate_owner_agreement(assisted_property_post_agreement_uuid) do
    with %AssistedPropertyPostAgreement{} = assisted_property_post_agreement <- Repo.get_by(AssistedPropertyPostAgreement, uuid: assisted_property_post_agreement_uuid),
         %DigioDoc{} = digio_doc <-
           DigioDocs.get_doc_details_by(%{entity_type: AssistedPropertyPostAgreement.schema_name(), entity_id: assisted_property_post_agreement.id, is_active: true}) do
      identitfier_signer_map =
        Enum.reduce(digio_doc.signing_parties, %{}, fn signing_party, acc ->
          Map.put(acc, signing_party["identifier"], signing_party["pki_signature_details"])
        end)

      esign_link_map = digio_doc.esign_link_map

      validation_mssgs =
        Enum.reduce(esign_link_map, [], fn esign_details, acc ->
          identifier = esign_details["identifier"]
          sign_details = Map.get(identitfier_signer_map, identifier)
          is_this_sign_valid = not is_nil(sign_details) and sign_details["name"] == esign_details["signer_name"]

          error_msg =
            "Owner details didn't match for signed doc - Owner Name - #{esign_details["signer_name"]} , Name on Aadhar - #{sign_details["name"]} , Phone Number - #{identifier}"

          res =
            if not is_this_sign_valid do
              ApplicationHelper.notify_on_slack("-----------------------------#{error_msg}", ApplicationHelper.get_slack_channel())
              [error_msg]
            else
              []
            end

          acc ++ res
        end)

      {:ok, validation_mssgs}
    else
      nil -> {:error, :not_found}
    end
  end

  def get_document(assisted_property_post_agreement_uuid) do
    assisted_property_post_agreement = Repo.get_by(AssistedPropertyPostAgreement, uuid: assisted_property_post_agreement_uuid)

    if not is_nil(assisted_property_post_agreement) do
      {documents, number_of_documents} =
        get_all_documents(assisted_property_post_agreement.id)
        |> aggregate_docs_by_type()

      response = %{
        "documents" => documents,
        "total_count" => number_of_documents
      }

      {:ok, response}
    else
      {:error, "assisted property post agreement not found"}
    end
  end

  def get_all_documents(assisted_property_post_agreement_id, doc_type_filters \\ @doc_types_supported) do
    {docs, _number_of_documents} = Document.get_document(assisted_property_post_agreement_id, AssistedPropertyPostAgreement.schema_name(), true)

    Enum.filter(docs, fn doc -> doc.type in doc_type_filters end)
    |> Enum.map(fn doc -> %{doc_url: doc[:doc_url], priority: doc[:priority], type: doc[:type], doc_name: doc[:doc_name]} end)
  end

  def aggregate_docs_by_type(docs) do
    {Enum.reduce(docs, %{}, fn x, acc -> Map.put(acc, x[:type], Map.get(acc, x[:type], []) ++ [x]) end), length(docs)}
  end

  defp assisted_properties_filter_query(:resale, params) do
    page =
      case params["page"] do
        nil ->
          1

        p when is_integer(p) ->
          p

        p when is_binary(p) ->
          {val, _} = Integer.parse(p)
          val
      end

    size =
      case params["size"] do
        nil ->
          15

        s when is_integer(s) ->
          s

        s when is_binary(s) ->
          {val, _} = Integer.parse(s)
          val
      end

    query =
      AssistedPropertyPostAgreement
      |> join(:inner, [a], b in Building, on: a.building_id == b.id)
      |> join(:inner, [a, _b], r in ResalePropertyPost, on: a.resale_property_post_id == r.id)
      |> join(:inner, [_a, _b, r], o in Owner, on: r.assigned_owner_id == o.id)

    query =
      if not is_nil(params["status"]) do
        query |> where([a, _b, _r, _o], a.status == ^params["status"])
      else
        query
      end

    query =
      if not is_nil(params["owner_name"]) do
        modified_search_text = "%" <> params["owner_name"] <> "%"
        query |> where([a, _b, _r, o], ilike(o.name, ^modified_search_text))
      else
        query
      end

    query =
      if not is_nil(params["owner_phone_number"]) do
        modified_search_text = "%" <> params["owner_phone_number"] <> "%"
        query |> where([a, _b, _r, o], ilike(o.phone_number, ^modified_search_text))
      else
        query
      end

    query =
      if not is_nil(params["building_name"]) do
        modified_search_text = "%" <> params["building_name"] <> "%"
        query |> where([a, b, _r, _o], ilike(b.name, ^modified_search_text))
      else
        query
      end

    query =
      if not is_nil(params["building_id"]),
        do: query |> where([a, _b, _r, _o], a.building_id == ^params["building_id"]),
        else: query

    query =
      if not is_nil(params["assigned_by_id"]),
        do: query |> where([a, _b, _r, _o], a.assigned_by_id == ^params["assigned_by_id"]),
        else: query

    query =
      if not is_nil(params["assisted_by_id"]),
        do: query |> where([a, _b, _r, _o], a.assisted_by_id == ^params["assisted_by_id"]),
        else: query

    content_query =
      query
      |> order_by([a, _b, _r, _o], desc: a.updated_at)
      |> limit(^(size + 1))
      |> offset(^((page - 1) * size))

    {query, content_query, page, size}
  end

  defp create_assisted_property_map(assisted_property) do
    {documents, number_of_documents} =
      get_all_documents(assisted_property.id)
      |> aggregate_docs_by_type()

    city = City.get_city_by_id(assisted_property.building.polygon.city_id)

    cc =
      if not is_nil(assisted_property.resale_property_post.assigned_owner) && not is_nil(assisted_property.resale_property_post.assigned_owner.country_code),
        do: assisted_property.resale_property_post.assigned_owner.country_code,
        else: "+91"

    owner_details =
      if not is_nil(assisted_property.resale_property_post.assigned_owner) do
        %{
          name: assisted_property.resale_property_post.assigned_owner && assisted_property.resale_property_post.assigned_owner.name,
          phone_number: assisted_property.resale_property_post.assigned_owner && assisted_property.resale_property_post.assigned_owner.phone_number,
          country_code: cc
        }
      else
        %{}
      end

    %{
      assisted_property_id: assisted_property.id,
      assisted_property_uuid: assisted_property.uuid,
      notes: assisted_property.notes,
      status: assisted_property.status,
      owner_agreement_status: assisted_property.owner_agreement_status,
      assigned_by: %{
        employee_id: assisted_property.assigned_by.id,
        employee_role_id: assisted_property.assigned_by.employee_role_id,
        employee_uuid: assisted_property.assigned_by.uuid,
        name: assisted_property.assigned_by.name,
        phone_number: assisted_property.assigned_by.phone_number
      },
      assisted_by: %{
        employee_id: assisted_property.assisted_by.id,
        employee_role_id: assisted_property.assisted_by.employee_role_id,
        employee_uuid: assisted_property.assisted_by.uuid,
        name: assisted_property.assisted_by.name,
        phone_number: assisted_property.assisted_by.phone_number
      },
      updated_by: %{
        name: assisted_property.updated_by.name,
        phone_number: assisted_property.updated_by.phone_number
      },
      documents: documents,
      document_size: number_of_documents,
      building: %{
        id: assisted_property.building.id,
        uuid: assisted_property.building.uuid,
        name: assisted_property.building.name,
        display_address: assisted_property.building.display_address,
        polygon_name: assisted_property.building.polygon.name,
        city_name: city.name,
        city_id: city.id
      },
      post: %{
        uuid: assisted_property.resale_property_post.uuid,
        price: assisted_property.resale_property_post.price,
        carpet_area: assisted_property.resale_property_post.carpet_area,
        parking: assisted_property.resale_property_post.parking,
        configuration: assisted_property.resale_property_post.configuration_type.name,
        owner: owner_details,
        source: assisted_property.resale_property_post.source,
        is_offline: assisted_property.resale_property_post.is_offline,
        verified: assisted_property.resale_property_post.is_verified,
        configuration_type_id: assisted_property.resale_property_post.configuration_type_id,
        floor_type_id: assisted_property.resale_property_post.floor_type_id
      },
      inserted_at: assisted_property.inserted_at |> Time.naive_to_epoch_in_sec(),
      updated_at: assisted_property.updated_at |> Time.naive_to_epoch_in_sec()
    }
  end
end
