defmodule Gossip.Messenger do
  def start_link do
    Agent.start_link(fn ->
      %{id: 1, uuid: UUID.uuid4(), msgs: MapSet.new()}
    end)
  end

  def pack!(pid, content) do
    {uuid, id} =
      Agent.get_and_update(pid, fn map ->
        {{map.uuid, map.id}, %{map | id: map.id + 1}}
      end)

    Msgpax.pack!(%{id: "#{uuid}-#{id}", content: content})
  end

  def unpack(pid, msg) do
    case Msgpax.unpack(msg) do
      {:ok, unpacked_msg} -> validate_msg(pid, unpacked_msg)
      _ -> nil
    end
  end

  defp validate_msg(pid, %{"id" => msg_id, "content" => content}) do
    %{uuid: uuid, msgs: msgs} = Agent.get(pid, fn map -> map end)

    cond do
      String.starts_with?(msg_id, uuid) ->
        nil

      MapSet.member?(msgs, msg_id) ->
        nil

      true ->
        Agent.update(pid, fn map ->
          new_msgs = MapSet.put(msgs, msg_id)
          %{map | msgs: new_msgs}
        end)

        content
    end
  end
end
