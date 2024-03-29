defmodule P3tr.Discord.Topic do
  require P3tr.Gettext
  use Discord.Commands, otp_app: :p3tr

  command "topic", "Topic Management" do
    subcommand("prompt", "Send prompt")

    sub_command_group "config", "Topic Configuration" do
      subcommand "add", "Add a topic" do
        string("key", "Topic Key", required: true)
        string("name", "Topic name", required: true)
        string("description", "Topic description")
        string("color", "Topic color")
      end

      subcommand "remove", "Remove a topic" do
        role("topic", "Topic role", required: true)
      end

      subcommand("remove-all", "Remove all topics")
    end
  end

  def command("topic", ["prompt" | _], interaction) do
    buttons = [
      button(:primary, custom_id: "topic_prompt", label: "Select topics")
    ]

    embed = %{
      type: :rich,
      title: "Please select topics your are interested in",
      color: 0xC13584
    }

    Nostrum.Api.create_message!(interaction.channel_id,
      embeds: [embed],
      components: [action_row(buttons)]
    )

    Nostrum.Api.create_interaction_response(
      interaction,
      interaction_response(:channel_message_with_source, flags: :ephemeral, content: "send prompt")
    )
  end

  def command("topic", ["config" | args], interaction) do
    Nostrum.Api.create_interaction_response(
      interaction,
      interaction_response(:deferred_channel_message_with_source, flags: :ephemeral)
    )

    embeds = config(args, interaction)

    Nostrum.Api.edit_interaction_response(
      interaction,
      interaction_response_data(embeds: embeds)
    )
  end

  def component("topic", ["prompt"], interaction) do
    Nostrum.Api.create_interaction_response(
      interaction,
      interaction_response(:deferred_channel_message_with_source, flags: :ephemeral)
    )

    prompt(interaction)
    |> case do
      [] ->
        Nostrum.Api.edit_interaction_response(
          interaction,
          interaction_response_data(content: "No topics found")
        )

      options ->
        Nostrum.Api.edit_interaction_response(
          interaction,
          interaction_response_data(
            content: "Select topics",
            components: [
              action_row([select_menu(:string_select, "topic_select", options: options)])
            ]
          )
        )
    end
  end

  def component("topic", ["select"], interaction) do
    Nostrum.Api.create_interaction_response(
      interaction,
      interaction_response(:deferred_update_channel, flags: :ephemeral)
    )

    guild = interaction.guild_id

    values =
      interaction.data.values
      |> Stream.map(&String.split(&1, "_"))
      |> Stream.map(&List.last/1)
      |> Stream.map(&P3tr.Repo.Topic.get(guild, &1))
      |> Enum.into([])

    member_roles = interaction.member.roles
    member_id = interaction.member.user.id

    topics = P3tr.Repo.Topic.get_all(guild)

    removed_topics =
      topics
      |> Enum.filter(fn %P3tr.Repo.Topic{} = topic -> !Enum.member?(values, topic) end)
      |> Enum.filter(fn %P3tr.Repo.Topic{role_id: role_id} ->
        Enum.member?(member_roles, role_id)
      end)
      |> Stream.map(&apply_topic(:del, guild, member_id, &1))
      |> Enum.into([])

    added_topics =
      values
      |> Enum.filter(fn %P3tr.Repo.Topic{role_id: role_id} ->
        !Enum.member?(member_roles, role_id)
      end)
      |> Stream.map(&apply_topic(:add, guild, member_id, &1))
      |> Enum.into([])

    failed_remove =
      Enum.filter(removed_topics, fn
        {:error, _} -> true
        _ -> false
      end)

    failed_add =
      Enum.filter(added_topics, fn
        {:error, _} -> true
        _ -> false
      end)

    if failed_remove != [] or failed_add != [] do
      Nostrum.Api.edit_interaction_response!(
        interaction,
        interaction_response_data(content: "Failed to update topics")
      )
    else
      Nostrum.Api.edit_interaction_response!(
        interaction,
        interaction_response_data(content: "Updated topics")
      )
    end
  end

  defp apply_topic(:del, guild, user_id, role) do
    Nostrum.Api.remove_guild_member_role(guild, user_id, role.role_id, "User Topic change")
  end

  defp apply_topic(:add, guild, user_id, role) do
    Nostrum.Api.add_guild_member_role(guild, user_id, role.role_id, "User Topic change")
  end

  defp prompt(interaction) do
    member_roles = interaction.member.roles

    options =
      P3tr.Repo.Topic.get_all(interaction.guild_id)
      |> Enum.map(fn %P3tr.Repo.Topic{key: key, name: name, description: description, role_id: id} ->
        select_option(name, "topic_select_#{key}",
          description: description,
          default: Enum.member?(member_roles, id)
        )
      end)
  end

  defp config(["add", args: args], interaction) do
    key = Commands.fetch!(args, "key")
    name = Commands.get(args, "name")
    description = Commands.get(args, "description")
    # TODO: Keyword.get(args, :color)
    color = 0x00FF00

    create_topic(interaction.guild_id, key, name, description, color)
    |> case do
      {:ok, role} ->
        [
          %{
            type: :rich,
            title: "Created Role",
            description: "Role <@&#{role.role_id}> created for `#{key}`",
            color: color
          }
        ]

      {:error, {:already_exists, name}} ->
        [
          %{
            type: :rich,
            title: "Failed to create role",
            description: "Role `#{name}` already exists",
            color: 0xFF3333
          }
        ]

      {:error, :role_create_failed} ->
        [
          %{
            type: :rich,
            title: "Failed to create role",
            description: "Failed to create",
            color: 0xFF3333
          }
        ]
    end
  end

  defp config(["remove", args: args], interaction) do
    role = Commands.fetch!(args, "topic")

    msg =
      with role when not is_nil(role) <- P3tr.Repo.Topic.get(interaction.guild_id, role),
           :ok <- P3tr.Discord.delete_role(interaction.guild_id, role.role_id),
           {:ok, role} <- P3tr.Repo.Topic.remove(role) do
        %{
          type: :rich,
          title: "Removed Role",
          description: "Role `#{role.name}` removed",
          color: 0x00FF00
        }
      else
        nil ->
          %{
            type: :rich,
            title: "Failed to remove role",
            description: "Role <@&#{role}> not found",
            color: 0xFF3333
          }
      end

    [msg]
  end

  defp config(["remove-all", args: _args], interaction) do
    roles = P3tr.Repo.Topic.get_all(interaction.guild_id)

    result =
      roles
      |> Enum.map(fn role ->
        {role, P3tr.Discord.delete_role(interaction.guild_id, role.role_id, "Removed by admin")}
      end)
      |> Enum.map(fn
        {role, :ok} -> P3tr.Repo.Topic.remove(role)
        {_role, {:error, error}} -> {:error, error}
      end)

    failed =
      result
      |> Enum.filter(&match?({:error, _}, &1))
      # unwrap from error tuple
      |> Enum.map(fn
        {:error, inner} -> inner
        _ -> raise "unexpected"
      end)
      |> Enum.map(&format_error/1)
      |> Enum.join("\n")

    ok =
      result
      |> Enum.filter(&match?({:ok, _}, &1))
      # unwrap from ok tuple
      |> Enum.map(fn
        {:ok, %{key: key}} -> "- `#{key}`"
        _ -> raise "unexpected"
      end)
      |> Enum.join("\n")

    fields =
      [{"Deleted", ok}, {"Failed", failed}]
      |> Enum.map(fn
        {_, ""} -> nil
        v -> v
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn {name, msg} -> %{name: name, value: msg} end)

    [
      %{
        type: :rich,
        title: "Removed all Topics",
        color: 0x00FF00,
        fields: fields
      }
    ]
  end

  defp create_topic(guild, key, name, description, color) do
    with false <- P3tr.Repo.Topic.exists?(guild, key),
         {:ok, role} <- P3tr.Discord.create_role(__MODULE__, guild, name, color: color),
         {:ok, role} <- P3tr.Repo.Topic.create(guild, role, key, name, description) do
      {:ok, role}
    else
      true ->
        {:error, :topic_exists}

      {:error, %Ecto.Changeset{} = changeset} ->
        Nostrum.Api.delete_guild_role(guild, Ecto.Changeset.get_field(changeset, :role_id))
        IO.inspect(changeset)
        {:error, :role_create_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_error({:already_exists, key}), do: "- Pronoun `#{key}` already exists"
  defp format_error({:invalid_changeset, changeset}), do: "- #{inspect(changeset)}"
  defp format_error(reason), do: "- #{inspect(reason)}"
end
