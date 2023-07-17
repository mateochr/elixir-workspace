defmodule Workspace.CliTest do
  use ExUnit.Case
  alias Workspace.Cli
  import ExUnit.CaptureIO
  import TestUtils

  doctest Workspace.Cli

  @valid_options [
    :affected,
    :ignore,
    :task,
    :execution_order,
    :execution_mode,
    :verbose,
    :workspace_path,
    :config_path
  ]

  describe "options/2" do
    test "with no extra options" do
      options = Cli.options(@valid_options)

      for option <- @valid_options do
        assert options[option] == Workspace.Cli.Options.option(option)
      end
    end

    test "raises if invalid option" do
      assert_raise ArgumentError, "invalid option :invalid", fn -> Cli.options([:invalid]) end
    end

    test "merges with extras and overrides" do
      extra = [
        verbose: [
          type: :string,
          doc: "another verbose"
        ],
        another_option: [
          type: :boolean,
          default: false,
          doc: "another option"
        ]
      ]

      options = Cli.options([:verbose, :affected], extra)

      assert options[:affected] == Cli.Options.option(:affected)
      refute options[:verbose] == Cli.Options.option(:verbose)
      assert options[:verbose] == extra[:verbose]
      assert options[:another_option] == extra[:another_option]
    end
  end

  describe "log/2" do
    test "with default options" do
      assert capture_io(fn ->
               Cli.log("a message")
             end) =~ format_ansi(["==> ", "a message"])
    end

    test "with prefix set" do
      assert capture_io(fn ->
               Cli.log("a message", prefix: "++> ")
             end) =~ format_ansi(["++> ", "a message"])

      assert capture_io(fn ->
               Cli.log("a message", prefix: false)
             end) =~ "a message"
    end

    test "with a highlighted message" do
      assert capture_io(fn ->
               Cli.log([:bright, :red, "a message"], prefix: "--> ")
             end) =~ format_ansi(["--> ", :bright, :red, "a message"])
    end
  end

  describe "log_with_title/3" do
    test "with default options" do
      assert capture_io(fn ->
               Cli.log_with_title("section", "a message")
             end) =~ format_ansi(["==> ", "section", " - ", "a message"])
    end

    test "with options set" do
      assert capture_io(fn ->
               Cli.log_with_title(
                 Cli.highlight("section", :red),
                 Cli.highlight("a message", :bright),
                 prefix: "~>",
                 separator: ":"
               )
             end) =~
               format_ansi(["~>", :red, "section", :reset, ":", :bright, "a message", :reset])
    end
  end

  describe "project_name/2" do
    test "with show_status set to true" do
      opts = [show_status: true]
      project = project_fixture(app: :foo)

      # default status
      assert_ansi_lists(Cli.project_name(project, opts), [
        :light_cyan,
        ":foo",
        :reset,
        :bright,
        :green,
        " ✔",
        :reset
      ])

      # affected
      project = Workspace.Project.set_status(project, :affected)

      assert_ansi_lists(Cli.project_name(project, opts), [
        :yellow,
        ":foo",
        :reset,
        :bright,
        :yellow,
        " ●",
        :reset
      ])

      # modified
      project = Workspace.Project.set_status(project, :modified)

      assert_ansi_lists(Cli.project_name(project, opts), [
        :bright,
        :red,
        ":foo",
        :reset,
        :bright,
        :red,
        " ✚",
        :reset
      ])
    end

    test "with default options" do
      project = project_fixture(app: :foo)

      assert_ansi_lists(Cli.project_name(project, []), [:light_cyan, ":foo", :reset])
    end

    test "with a default_style set" do
      project = project_fixture(app: :foo)
      opts = [default_style: [:bright, :green]]

      assert_ansi_lists(Cli.project_name(project, opts), [:bright, :green, ":foo", :reset])
    end
  end

  test "newline/0" do
    assert capture_io(fn -> Cli.newline() end) == "\n"
  end

  defp assert_ansi_lists(output, expected) do
    assert List.flatten(output) == List.flatten(expected)
  end
end
