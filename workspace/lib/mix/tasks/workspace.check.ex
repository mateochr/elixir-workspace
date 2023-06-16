defmodule Mix.Tasks.Workspace.Check do
  @options_schema Workspace.Cli.global_opts() |> Keyword.take([:workspace_path, :config_path])

  @shortdoc "Runs configured checkers on the current workspace"

  @moduledoc """

  ## Command Line Options

  #{CliOpts.docs(@options_schema)}
  """

  use Mix.Task

  alias Workspace.Cli

  def run(argv) do
    %{parsed: opts, args: _args, extra: _extra} = CliOpts.parse!(argv, @options_schema)
    workspace_path = Keyword.get(opts, :workspace_path, File.cwd!())
    config_path = Keyword.fetch!(opts, :config_path)

    config = Workspace.config(Path.join(workspace_path, config_path))

    ensure_checks(config.checks)

    workspace = Workspace.new(workspace_path, config)

    config.checks
    |> Enum.map(fn {module, opts} -> module.check(workspace, opts) end)
    |> List.flatten()
    |> Enum.group_by(fn result -> result.project.app end)
    |> Enum.each(fn {app, results} -> print_project_status(app, results) end)
  end

  defp ensure_checks(checks) do
    if checks == [] do
      # TODO: improve the error message, add an example
      Mix.raise("No checkers config found in workspace config")
    end
  end

  defp print_project_status(app, results) do
    Cli.info(
      "#{app}",
      "",
      prefix: "==> "
    )

    Enum.each(results, fn result ->
      case result.status do
        :ok ->
          Cli.success("#{result.checker}", "OK", prefix: "\t")

        :error ->
          Cli.error("#{result.checker}", "ERROR", prefix: "\t")
          IO.ANSI.Docs.print(result.error, "text/markdown")
      end
    end)
  end
end
