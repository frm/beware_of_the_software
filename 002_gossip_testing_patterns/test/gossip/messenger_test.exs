defmodule Gossip.MessengerTest do
  use ExUnit.Case

  alias Gossip.Messenger

  setup do
    {:ok, messenger} = Messenger.start_link()

    {:ok, messenger: messenger}
  end

  describe "pack!/2" do
    test "correctly packs the message", %{messenger: messenger} do
      msg = "beware"
      uuid = Agent.get(messenger, & &1.uuid)

      packed_msg = Messenger.pack!(messenger, msg)

      %{"id" => id, "content" => content} = Msgpax.unpack!(packed_msg)
      assert id == "#{uuid}-1"
      assert content == "beware"
    end

    test "updates the message id counter", %{messenger: messenger} do
      msg = "of the software"

      Messenger.pack!(messenger, msg)

      assert 2 = Agent.get(messenger, & &1.id)
    end
  end
end
