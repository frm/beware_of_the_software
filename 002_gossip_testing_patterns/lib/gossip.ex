defmodule Gossip do
  @default_port 3000

  alias Gossip.Messenger

  use GenServer

  def start_link(args \\ []) do
    port = Keyword.get(args, :port, @default_port)
    callback = Keyword.fetch!(args, :callback)
    {:ok, server} = start_server(port)
    {:ok, messenger} = Messenger.start_link()

    args = [
      port: port,
      server: server,
      messenger: messenger,
      callback: callback
    ]

    GenServer.start_link(__MODULE__, args, [])
  end

  def connect_to(pid, host, port) do
    GenServer.call(pid, {:connect_to, host, port})
  end

  def broadcast(pid, msg) do
    GenServer.cast(pid, {:broadcast, msg})
  end

  def accept(pid, socket) do
    GenServer.cast(pid, {:accept, socket})
  end

  def recv(pid, msg) do
    GenServer.cast(pid, {:recv, msg})
  end

  def init(args) do
    state = %{
      port: args[:port],
      server: args[:server],
      messenger: args[:messenger],
      callback: args[:callback],
      neighbours: []
    }

    {:ok, state}
  end

  def handle_call({:connect_to, host, port}, _from, state) do
    {reply, new_state} =
      case :gen_tcp.connect(host, port, []) do
        {:ok, socket} ->
          {:ok, pid} = start_worker(socket)
          neighbours = [pid | state.neighbours]

          {:ok, %{state | neighbours: neighbours}}

        {:error, _} = error ->
          {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_cast({:broadcast, msg}, %{neighbours: neighbours} = state) do
    state.messenger
    |> Messenger.pack!(msg)
    |> do_broadcast(neighbours)

    {:noreply, state}
  end

  def handle_cast({:accept, socket}, state) do
    {:ok, pid} = start_worker(socket)
    neighbours = [pid | state.neighbours]

    {:noreply, %{state | neighbours: neighbours}}
  end

  def handle_cast({:recv, msg}, state) do
    unpacked_msg = Messenger.unpack(state.messenger, msg)

    unless is_nil(unpacked_msg) do
      state.callback.(unpacked_msg)
      do_broadcast(msg, state.neighbours)
    end

    {:noreply, state}
  end

  defp start_server(port) do
    Supervisor.start_link(
      [
        {Gossip.Server, [self(), port]}
      ],
      strategy: :one_for_one
    )
  end

  defp start_worker(socket) do
    {:ok, pid} = Gossip.Worker.start([self(), socket])
    :gen_tcp.controlling_process(socket, pid)

    {:ok, pid}
  end

  defp do_broadcast(msg, neighbours) do
    Enum.each(neighbours, fn n ->
      send(n, {:send, msg})
    end)
  end
end
