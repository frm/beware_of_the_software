defmodule GossipTest do
  use ExUnit.Case
  doctest Gossip

  import Mock

  describe "handle_call/3 for :connect_to messages" do
    test "correctly connects to a different node" do
      port = 3000
      pid = self()
      state = %{neighbours: []}
      start_server(port)

      Gossip.handle_call({:connect_to, 'localhost', port}, pid, state)

      assert_receive {:connected, _}
    end

    test "updates the neighbour list" do
      port = 3000
      pid = self()
      state = %{neighbours: []}
      start_server(port)

      {:reply, _, new_state} = Gossip.handle_call({:connect_to, 'localhost', port}, pid, state)

      assert %{neighbours: [_]} = new_state
    end

    test "starts a new worker" do
      pid = self()
      port = 3000
      state = %{neighbours: []}
      start_server(port)

      with_mock(
        Gossip.Worker,
        start: fn _ ->
          send(pid, :started)
          {:ok, pid}
        end
      ) do
        Gossip.handle_call({:connect_to, 'localhost', port}, pid, state)

        assert_receive :started
      end
    end
  end

  describe "handle_cast/2 for :broadcast messages" do
    test "sends a message to every neighbour worker" do
      pid = self()
      {:ok, messenger} = Gossip.Messenger.start_link()

      state = %{
        neighbours: [pid],
        messenger: messenger
      }

      msg = "beware"

      Gossip.handle_cast({:broadcast, msg}, state)

      assert_receive {:send, _packed_msg}
    end
  end

  describe "handle_cast/2 for :accept messages" do
    test "starts a worker for the new node" do
      pid = self()
      port = 3000
      state = %{neighbours: []}
      start_server(port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [])

      with_mock(
        Gossip.Worker,
        start: fn _ ->
          send(pid, :started)
          {:ok, pid}
        end
      ) do
        Gossip.handle_cast({:accept, socket}, state)

        assert_receive :started
      end
    end

    test "updates the state with the new neighbour" do
      pid = self()
      port = 3000
      state = %{neighbours: []}
      start_server(port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [])

      with_mock Gossip.Worker, start: fn _ -> {:ok, pid} end do
        {:noreply, new_state} = Gossip.handle_cast({:accept, socket}, state)

        assert %{neighbours: [^pid]} = new_state
      end
    end
  end

  describe "handle_cast/2 for :recv messages" do
    test "calls the callback" do
      pid = self()
      callback = fn msg -> send(pid, {:callback, msg}) end
      {:ok, messenger} = Gossip.Messenger.start_link()
      state = %{neighbours: [], messenger: messenger, callback: callback}
      msg = %{content: "beware of the software", id: "123-1"} |> Msgpax.pack!()

      Gossip.handle_cast({:recv, msg}, state)

      assert_receive {:callback, "beware of the software"}
    end

    test "broadcasts the message to the neighbours" do
      pid = self()
      callback = fn msg -> send(pid, {:callback, msg}) end
      {:ok, messenger} = Gossip.Messenger.start_link()
      state = %{neighbours: [pid], messenger: messenger, callback: callback}
      msg = %{content: "beware of the software", id: "123-1"} |> Msgpax.pack!()

      Gossip.handle_cast({:recv, msg}, state)

      assert_receive {:send, ^msg}
    end
  end

  defp start_server(port) do
    pid = self()

    Task.start(fn ->
      socket_opts = [:binary, packet: 0, active: true, reuseaddr: true]

      {:ok, server_socket} = :gen_tcp.listen(port, socket_opts)
      {:ok, socket} = :gen_tcp.accept(server_socket)

      :gen_tcp.controlling_process(socket, pid)

      send(pid, {:connected, socket})
    end)
  end
end
