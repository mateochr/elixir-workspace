defmodule Workspace.Graph do
  @moduledoc """
  Workspace path dependencies graph and helper utilities
  """

  @type vertices :: [:digraph.vertex()]

  @doc """
  Runs the given `callback` on the workspace's graph

  `callback` should be a function expecting as input a `:digraph.graph()`.
  """
  @spec with_digraph(workspace :: Workspace.t(), callback :: (:digraph.graph() -> result)) ::
          result
        when result: term()
  def with_digraph(workspace, callback) do
    graph = digraph(workspace)

    try do
      callback.(graph)
    after
      :digraph.delete(graph)
    end
  end

  @doc """
  Generates a graph of the given workspace.

  Notice that you need to manually delete the graph. Prefer instead
  `with_digraph/2`.
  """
  @spec digraph(workspace :: Workspace.t()) :: :digraph.graph()
  def digraph(workspace) do
    graph = :digraph.new()

    for project <- workspace.projects do
      :digraph.add_vertex(graph, project.app)
    end

    for project <- workspace.projects,
        {dep, dep_config} <- project.config[:deps],
        path_dependency?(dep_config) do
      :digraph.add_edge(graph, project.app, dep)
    end

    graph
  end

  defp path_dependency?(config) when is_binary(config), do: false
  defp path_dependency?(config), do: config[:path] != nil

  @doc """
  Return the source projects of the workspace
  """
  @spec source_projects(workspace :: Workspace.t()) :: vertices()
  def source_projects(workspace) do
    with_digraph(workspace, fn graph -> :digraph.source_vertices(graph) end)
  end

  @doc """
  Return the sink projects of the workspace
  """
  @spec sink_projects(workspace :: Workspace.t()) :: vertices()
  def sink_projects(workspace) do
    with_digraph(workspace, fn graph -> :digraph.sink_vertices(graph) end)
  end

  @doc """
  Get the affected workspace's projects given the changed projects
  """
  @spec affected(workspace :: Workspace.t(), projects :: vertices()) :: vertices()
  def affected(workspace, projects) do
    with_digraph(workspace, fn graph ->
      :digraph_utils.reaching_neighbours(projects, graph)
      |> Enum.concat(projects)
      |> Enum.uniq()
    end)
  end

  @doc """
  Prints the workspace tree.

  Delegates to `Mix.Utils.print_tree`.
  """
  @spec print_tree(workspace :: Workspace.t()) :: binary()
  def print_tree(workspace) do
    with_digraph(workspace, fn graph ->
      callback = fn {node, _format} ->
        children =
          :digraph.out_neighbours(graph, node)
          |> Enum.map(fn node -> {node, nil} end)
          |> Enum.sort()

        {{Atom.to_string(node), nil}, children}
      end

      root_nodes =
        graph
        |> :digraph.source_vertices()
        |> Enum.map(fn node -> {node, nil} end)
        |> Enum.sort()

      Mix.Utils.print_tree(root_nodes, callback)
    end)
  end
end
