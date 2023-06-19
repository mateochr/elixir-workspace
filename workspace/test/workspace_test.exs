defmodule WorkspaceTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  doctest Workspace

  @sample_workspace_path "test/fixtures/sample_workspace"

  describe "config/1" do
    test "warning with invalid file" do
      assert capture_io(:stderr, fn ->
               config = Workspace.config("invalid.exs")
               assert config == %Workspace.Config{}
             end) =~ "file not found"
    end

    test "with incorrect contents" do
      assert capture_io(:stderr, fn ->
               config = Workspace.config("test/fixtures/configs/invalid_contents.exs")
               assert config == %Workspace.Config{}
             end) =~ "invalid config options given to workspace config: [:invalid]"
    end

    test "with valid config" do
      config = Workspace.config("test/fixtures/configs/valid.exs")
      assert %Workspace.Config{} = config
      assert config.ignore_projects == [Dummy.MixProject, Foo.MixProject]
      assert config.ignore_paths == ["path/to/foo"]
    end
  end

  describe "new/1" do
    test "creates a workspace struct" do
      workspace = Workspace.new(@sample_workspace_path)

      assert %Workspace{} = workspace
      assert length(workspace.projects) == 11
    end

    test "with ignore_projects set" do
      config = %Workspace.Config{
        ignore_projects: [
          ProjectA.MixProject,
          ProjectB.MixProject
        ]
      }

      workspace = Workspace.new(@sample_workspace_path, config)

      assert %Workspace{} = workspace
      assert length(workspace.projects) == 9
    end

    test "with ignore_paths set" do
      config = %Workspace.Config{
        ignore_paths: [
          "project_a",
          "project_b",
          "project_c"
        ]
      }

      workspace = Workspace.new(@sample_workspace_path, config)

      assert %Workspace{} = workspace
      assert length(workspace.projects) == 8
    end

    test "raises if the path is not a workspace" do
      assert_raise Mix.Error, ~r"to be a workspace project", fn ->
        Workspace.new(Path.join(@sample_workspace_path, "project_a"))
      end
    end
  end

  describe "workspace?/1" do
    test "relative/absolute paths to valid projects" do
      assert Workspace.workspace?(@sample_workspace_path)
      assert Workspace.workspace?(Path.expand(@sample_workspace_path))

      assert Workspace.workspace?(Path.join(@sample_workspace_path, "mix.exs"))
      assert Workspace.workspace?(Path.join(@sample_workspace_path, "mix.exs") |> Path.expand())

      refute Workspace.workspace?(Path.join(@sample_workspace_path, "project_a"))
      refute Workspace.workspace?(Path.join(@sample_workspace_path, "project_a") |> Path.expand())
    end

    test "raises if not valid project" do
      assert_raise ArgumentError, fn ->
        Workspace.workspace?(Path.join(@sample_workspace_path, "invalid"))
      end
    end

    test "with project config" do
      workspace_config =
        Path.join(@sample_workspace_path, "mix.exs") |> Workspace.Project.config()

      project_config =
        Path.join([@sample_workspace_path, "project_a", "mix.exs"]) |> Workspace.Project.config()

      assert Workspace.workspace?(workspace_config)
      refute Workspace.workspace?(project_config)
    end
  end
end
