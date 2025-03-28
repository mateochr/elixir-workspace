defmodule WorkspaceTest do
  use ExUnit.Case
  import Workspace.TestUtils
  doctest Workspace

  setup do
    project_a = project_fixture(app: :foo)
    project_b = project_fixture(app: :bar)

    workspace = workspace_fixture([project_a, project_b])

    %{workspace: workspace}
  end

  describe "new/2" do
    @tag :tmp_dir
    test "creates a workspace struct", %{tmp_dir: tmp_dir} do
      Workspace.Test.with_workspace(tmp_dir, [], :default, fn ->
        {:ok, workspace} = Workspace.new(tmp_dir)

        assert %Workspace.State{} = workspace
        refute workspace.status_updated?
        assert map_size(workspace.projects) == 11
        assert length(:digraph.vertices(workspace.graph)) == 11
        assert length(:digraph.source_vertices(workspace.graph)) == 4
      end)
    end

    @tag :tmp_dir
    test "with ignore_projects set", %{tmp_dir: tmp_dir} do
      Workspace.Test.with_workspace(tmp_dir, [], :default, fn ->
        config = [
          ignore_projects: [
            PackageA.MixProject,
            PackageB.MixProject
          ]
        ]

        {:ok, workspace} = Workspace.new(tmp_dir, config)

        assert %Workspace.State{} = workspace
        refute workspace.status_updated?
        assert map_size(workspace.projects) == 9
        assert length(:digraph.vertices(workspace.graph)) == 9
      end)
    end

    @tag :tmp_dir
    test "with ignore_paths set", %{tmp_dir: tmp_dir} do
      Workspace.Test.with_workspace(tmp_dir, [], :default, fn ->
        config = [
          ignore_paths: [
            "package_a",
            "package_b",
            "package_c"
          ]
        ]

        {:ok, workspace} = Workspace.new(tmp_dir, config)

        assert %Workspace.State{} = workspace
        refute workspace.status_updated?
        assert map_size(workspace.projects) == 8
        assert length(:digraph.vertices(workspace.graph)) == 8
      end)
    end

    @tag :tmp_dir
    test "error if the path is not a workspace", %{tmp_dir: tmp_dir} do
      Workspace.Test.with_workspace(tmp_dir, [], :default, fn ->
        assert {:error, reason} = Workspace.new(Path.join(tmp_dir, "package_a"))
        assert reason =~ "The project is not properly configured as a workspace"
        assert reason =~ "to be a workspace project. Some errors were detected"
      end)
    end

    test "error in case of an invalid path" do
      assert {:error, reason} = Workspace.new("/an/invalid/path")
      assert reason =~ "mix.exs does not exist"
      assert reason =~ "to be a workspace project. Some errors were detected"
    end

    test "raises with nested workspace" do
      message = "you are not allowed to have nested workspaces, :foo is defined as :workspace"

      assert_raise ArgumentError, message, fn ->
        project_a = project_fixture(app: :foo, workspace: [type: :workspace])
        workspace_fixture([project_a])
      end
    end

    test "error if two projects have the same name" do
      project_a = project_fixture([app: :foo], path: "packages")
      project_b = project_fixture([app: :foo], path: "tools")

      assert {:error, message} = Workspace.new("", "foo/mix.exs", [], [project_a, project_b])

      assert message == """
             You are not allowed to have multiple projects with the same name under
             the same workspace.

             * :foo is defined under: packages/foo/mix.exs, tools/foo/mix.exs
             """
    end
  end

  describe "new!/2" do
    @tag :tmp_dir
    test "error if the path is not a workspace", %{tmp_dir: tmp_dir} do
      Workspace.Test.with_workspace(tmp_dir, [], :default, fn ->
        assert_raise ArgumentError, ~r"to be a workspace project", fn ->
          Workspace.new!(Path.join(tmp_dir, "package_b"))
        end
      end)
    end
  end

  describe "project/2" do
    test "gets an existing project", %{workspace: workspace} do
      assert {:ok, _project} = Workspace.project(workspace, :foo)
    end

    test "error if invalid project", %{workspace: workspace} do
      assert {:error, ":invalid is not a member of the workspace"} =
               Workspace.project(workspace, :invalid)
    end
  end

  describe "project!/2" do
    test "gets an existing project", %{workspace: workspace} do
      assert project = Workspace.project!(workspace, :foo)
      assert project.app == :foo
    end

    test "raises if invalid project", %{workspace: workspace} do
      assert_raise ArgumentError, ":invalid is not a member of the workspace", fn ->
        Workspace.project!(workspace, :invalid)
      end
    end
  end

  test "project?/2", %{workspace: workspace} do
    assert Workspace.project?(workspace, :foo)
    refute Workspace.project?(workspace, :food)
  end

  test "projects/1 with order set" do
    zoo =
      Workspace.Test.project_fixture(:zoo, "zoo",
        deps: [{:foo, path: "../foo"}, {:bar, path: "../bar"}]
      )

    foo = Workspace.Test.project_fixture(:foo, "foo", deps: [{:baz, path: "../baz"}])
    bar = Workspace.Test.project_fixture(:bar, "bar", deps: [{:baz, path: "../baz"}])
    baz = Workspace.Test.project_fixture(:baz, "baz", deps: [])

    workspace = Workspace.Test.workspace_fixture([zoo, foo, bar, baz])

    # without any order the response is not deterministic, we just check that we get all expected projects
    assert Workspace.projects(workspace) |> Enum.count() == 4

    # alphabetical order
    assert Workspace.projects(workspace, order: :alphabetical) |> Enum.map(& &1.app) == [
             :bar,
             :baz,
             :foo,
             :zoo
           ]

    # postorder, again the response is not deterministic but the order should
    # respect the graph topology
    projects =
      Workspace.projects(workspace, order: :postorder) |> Enum.map(& &1.app) |> Enum.with_index()

    assert [{:baz, 0} | _rest] = projects
    assert projects[:bar] < projects[:zoo]
    assert projects[:foo] < projects[:zoo]
  end
end
