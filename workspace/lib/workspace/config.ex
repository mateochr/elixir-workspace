defmodule Workspace.Config do
  @test_coverage_schema [
    threshold: [
      type: :non_neg_integer,
      doc: """
      The overall coverage threshold for the workspace. If the overall test coverage is below this
      value then the `workspace.test.coverage` command is considered failed. Notice
      that the overall test coverage percentage is calculated only on the enabled projects.
      """,
      default: 90
    ],
    warning_threshold: [
      type: :non_neg_integer,
      doc: """
      If set it specifies an overall warning threshold under which a warning will be
      raised. If not set it is implied to be the mid value between `threshold` and `100`.
      """
    ],
    exporters: [
      type: :keyword_list,
      doc: """
      Definition of exporters to be used. Each defined exporter must be an anonymous
      function taking as input the `workspace` and the `coverage_stats`. For more
      details check the `Mix.Tasks.Workspace.Test.Coverage` task.
      """
    ],
    allow_failure: [
      type: {:list, :atom},
      doc: """
      A list of projects for which the test coverage is allowed to fail without affecting
      the overall status.
      """,
      default: []
    ]
  ]

  @options_schema NimbleOptions.new!(
                    ignore_projects: [
                      type: {:list, :atom},
                      doc: """
                      A list of project modules to be ignored. If set these projects will
                      not be considered workspace projects when initializing a `Workspace`
                      with the current config.
                      """,
                      default: []
                    ],
                    ignore_paths: [
                      type: {:list, :string},
                      doc: """
                      List of paths relative to the workspace root to be ignored from
                      parsing for projects detection.
                      """,
                      default: []
                    ],
                    checks: [
                      type: {:list, :keyword_list},
                      doc: """
                      List of checks configured for the workspace. For more details check
                      `Workspace.Check`
                      """,
                      default: []
                    ],
                    test_coverage: [
                      type: :keyword_list,
                      doc: """
                      Test coverage configuration for the workspace. Notice that this is
                      independent of the `test_coverage` configuration per project. It is
                      applied in the aggregate coverage and except thresholds you can
                      also configure coverage exporters.
                      """,
                      keys: @test_coverage_schema,
                      default: []
                    ]
                  )

  @moduledoc """
  A struct holding workspace configuration.

  ## Options

  The following configuration options are supported:

  #{NimbleOptions.docs(@options_schema)}

  > #### Extra Options {: .info}
  >
  > Notice that the validation will **not fail** if any extra configuration option
  > is present. This way various plugins or mix tasks may define their own options
  > that can be read from this configuration.
  """

  @doc """
  Loads the workspace config from the given path.

  An error tuple will be returned if the config is invalid.
  """
  @spec load(config_file :: String.t()) :: {:ok, keyword()} | {:error, binary()}
  def load(config_file) do
    config_file = Path.expand(config_file)

    with {:ok, config_file} <- Workspace.Helpers.ensure_file_exists(config_file),
         {config, _bindings} <- Code.eval_file(config_file) do
      {:ok, config}
    end
  end

  @doc """
  Validates that the given `config` is a valid `Workspace` config.

  A `config` is valid if:

  - it follows the workspace config schema
  - every check is valid, for more details check `Workspace.Check.validate/1`

  Returns either `{:ok, config}` with the updated `config` is it is valid, or
  `{:error, message}` in case of errors.
  """
  @spec validate(config :: keyword()) :: {:ok, keyword()} | {:error, binary()}
  def validate(config) do
    with {:ok, config} <- validate_config(config) do
      validate_checks(config)
    end
  end

  defp validate_config(config) when is_list(config) do
    default_options_config = Keyword.take(config, Keyword.keys(@options_schema.schema))

    # we only validate default options since extra options may be added by
    # plugins
    case NimbleOptions.validate(default_options_config, @options_schema) do
      {:ok, default_options_config} -> {:ok, Keyword.merge(config, default_options_config)}
      {:error, %NimbleOptions.ValidationError{message: message}} -> {:error, message}
    end
  end

  defp validate_config(config) do
    {:error, "expected workspace config to be a keyword list, got: #{inspect(config)}"}
  end

  defp validate_checks(config) do
    checks = config[:checks]

    case validate_checks(checks, [], []) do
      {:ok, checks} -> {:ok, Keyword.put(config, :checks, checks)}
      {:error, message} -> {:error, message}
    end
  end

  defp validate_checks([], checks, []), do: {:ok, :lists.reverse(checks)}

  defp validate_checks([], _checks, errors) do
    errors = :lists.reverse(errors) |> Enum.join("\n")
    {:error, "failed to validate checks:\n #{errors}"}
  end

  defp validate_checks([check | rest], acc, errors) do
    case Workspace.Check.validate(check) do
      {:ok, check} ->
        validate_checks(rest, [check | acc], errors)

      {:error, message} ->
        validate_checks(rest, acc, [message | errors])
    end
  end

  @doc """
  Same as `validate/1` but raises an `ArgumentError` exception in case of failure.

  In case of success the validated configuration keyword list is returned.
  """
  @spec validate!(config :: keyword()) :: keyword()
  def validate!(config) do
    case validate(config) do
      {:ok, config} -> config
      {:error, message} -> raise ArgumentError, message: message
    end
  end
end
