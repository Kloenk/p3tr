defmodule P3tr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      P3tr.Repo,
      P3tr.Discord
      # Starts a worker by calling: P3tr.Worker.start_link(arg)
      # {P3tr.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: P3tr.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
