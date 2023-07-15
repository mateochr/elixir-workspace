defmodule Mix.Tasks.Workspace.Test.CoverageTest do
  use ExUnit.Case

  require TestUtils

  import ExUnit.CaptureIO
  import TestUtils

  alias Mix.Tasks.Workspace.Test.Coverage, as: TestCoverageTask
  alias Mix.Tasks.Workspace.Run, as: RunTask

  setup do
    Application.put_env(:elixir, :ansi_enabled, false)
  end

  test "run tests and analyze coverage" do
    fixture_path = test_fixture_path()

    in_fixture("test_coverage", fn ->
      make_fixture_unique(fixture_path, 0)
    end)

    # first run the tests with --cover flag set
    capture_io(fn ->
      RunTask.run([
        "-t",
        "test",
        "--workspace-path",
        fixture_path,
        "--",
        "--cover"
      ])
    end)

    # check that the coverdata files were created
    assert File.exists?(Path.join([fixture_path, "package_0a/cover/package_0a.coverdata"]))
    assert File.exists?(Path.join([fixture_path, "package_0b/cover/package_0b.coverdata"]))
    assert File.exists?(Path.join([fixture_path, "package_0c/cover/package_0c.coverdata"]))

    # check test coverage task output
    captured =
      assert_raise_and_capture_io(
        Mix.Error,
        ~r"coverage for one or more projects below the required threshold",
        fn ->
          TestCoverageTask.run(["--workspace-path", fixture_path])
        end
      )

    expected =
      [
        "==> importing cover results",
        "==> :package_a - importing cover results from package_a/cover/package_a.coverdata",
        "==> :package_b - importing cover results from package_b/cover/package_b.coverdata",
        "==> :package_c - importing cover results from package_c/cover/package_c.coverdata",
        "==> analysing coverage data",
        "==> :package_a - total coverage 100.00% [threshold 90%]",
        "==> :package_b - total coverage 50.00% [threshold 90%]",
        "50.00%   PackageB (1/2 lines)",
        "==> :package_c - total coverage 25.00% [threshold 90%]",
        "25.00%   PackageC (1/4 lines)",
        "==> workspace coverage 42.86% [threshold 90%]"
      ]
      |> add_index_to_output(0)

    assert_cli_output_match(captured, expected)
  end

  test "test coverage on a single project" do
    fixture_path = test_fixture_path()

    # TODO: create another helper macro like create_fixture
    in_fixture("test_coverage", fn ->
      make_fixture_unique(fixture_path, 1)
      # make_modules_unique(1)
    end)

    # first run the tests with --cover flag set
    capture_io(fn ->
      RunTask.run([
        "-t",
        "test",
        "--workspace-path",
        fixture_path,
        "--",
        "--cover"
      ])
    end)

    # with a single project param set
    captured =
      capture_io(fn ->
        TestCoverageTask.run(["--workspace-path", fixture_path, "--project", "package_1a"])
      end)

    expected =
      [
        "==> importing cover results",
        "==> :package_a - importing cover results from package_a/cover/package_a.coverdata",
        "==> analysing coverage data",
        "==> :package_a - total coverage 100.00% [threshold 90%]",
        "==> workspace coverage 100.00% [threshold 90%]"
      ]
      |> add_index_to_output(1)

    assert_cli_output_match(captured, expected)
  end

  #
  # test "temp" do
  #   # # with an ignore project set
  #   # captured =
  #   #   assert_raise_and_capture_io(
  #   #     Mix.Error,
  #   #     ~r"coverage for one or more projects below the required threshold",
  #   #     fn ->
  #   #       TestCoverageTask.run(["--workspace-path", fixture_path, "--ignore", "package_a"])
  #   #     end
  #   #   )
  #   #
  #   # expected = [
  #   #   "==> importing cover results",
  #   #   "==> :package_b - importing cover results from package_b/cover/package_b.coverdata",
  #   #   "==> :package_c - importing cover results from package_c/cover/package_c.coverdata",
  #   #   "==> analysing coverage data",
  #   #   "==> :package_b - total coverage 100.00% [threshold 90%]",
  #   #   "==> :package_c - total coverage 100.00% [threshold 90%]",
  #   #   "==> workspace coverage 100.00% [threshold 90%]"
  #   # ]
  #   #
  #   # assert_cli_output_match(captured, expected)
  # end

  defp make_fixture_unique(fixture_path, index) do
    # replace the content of all ex and exs files
    Path.join(fixture_path, "**/*.{exs,ex}")
    |> Path.wildcard()
    |> Enum.each(&add_index_to_module(&1, index))

    # rename all package folders
    Path.join(fixture_path, "**/package_*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.each(fn path ->
      new_folder_name =
        path
        |> Path.basename()
        |> String.replace("package_", "package_#{index}")

      new_path =
        path
        |> Path.dirname()
        |> Path.join(new_folder_name)

      File.rename(path, new_path)
    end)
  end

  defp add_index_to_module(path, index) do
    content = File.read!(path)

    content =
      ["Workspace", "_workspace", "Package", "package_"]
      |> Enum.reduce(content, fn pattern, content ->
        String.replace(content, pattern, "#{pattern}#{index}")
      end)

    File.write(path, content)
  end

  defp add_index_to_output(lines, index) do
    Enum.map(lines, fn line ->
      line
      |> String.replace("package_", "package_#{index}")
      |> String.replace("Package", "Package#{index}")
    end)
  end
end
