defmodule Gossip.Worker do
  use Task
  @shrug "¯\\_(ツ)_/¯\n"

  def start(args) do
    Task.start(__MODULE__, :recv_loop, args)
  end

  def recv_loop(gossip, socket) do
    receive do
      {:tcp_closed, _port} ->
        :gen_tcp.close(socket)
        false

      {:tcp, _port, content} ->
        Gossip.recv(gossip, content)
        true

      {:send, msg} ->
        :gen_tcp.send(socket, msg)
        true

      msg ->
        IO.inspect(msg)
        true
    end and recv_loop(gossip, socket)
  end
end
