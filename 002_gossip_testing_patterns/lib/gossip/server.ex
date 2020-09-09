defmodule Gossip.Server do
  use Task

  @socket_opts [:binary, packet: 0, active: true, reuseaddr: true]

  def start_link(args) do
    Task.start_link(__MODULE__, :run, args)
  end

  def run(gossip, port) do
    {:ok, server_socket} = :gen_tcp.listen(port, @socket_opts)

    accept_loop(gossip, server_socket)
  end

  defp accept_loop(gossip, server_socket) do
    {:ok, socket} = :gen_tcp.accept(server_socket)

    :gen_tcp.controlling_process(socket, gossip)

    Gossip.accept(gossip, socket)
    accept_loop(gossip, server_socket)
  end
end
