defmodule Workspace.Graph do
  @moduledoc """
  Workspace path dependencies graph and helper utilities

  ## Internal representation of the graph

  Each graph node is a tuple of the form `{package_name, package_type}` where
  `package_type` is one of:

    * `:workspace` - for workspace internal projects
    * `:external` - for external projects / dependencies

  By default `:workspace` will always be included in the graph. On the other hand
  `:external` dependencies will be included only if the `:external` option is set
  to `true` during graph's construction.
  """

  @type vertices :: [:digraph.vertex()]

  @doc """
  Runs the given `callback` on the workspace's graph

  `callback` should be a function expecting as input a `:digraph.graph()`. For
  supported options check `digraph/2`
  """
  @spec with_digraph(
          workspace :: Workspace.t(),
          callback :: (:digraph.graph() -> result),
          opts :: keyword()
        ) ::
          result
        when result: term()
  def with_digraph(workspace, callback, opts \\ []) do
    graph = digraph(workspace, opts)

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

  ## Options

    * `:external` - if set external dependencies will be included as well
    * `:ignore` - if set the specified workspace projects will not be included
    in the graph
  """
  @spec digraph(workspace :: Workspace.t(), opts :: keyword()) :: :digraph.graph()
  def digraph(workspace, opts \\ []) do
    graph = :digraph.new()

    # add workspace vertices
    for {app, _project} <- workspace.projects,
        include_app?(app, opts[:ignore]) do
      :digraph.add_vertex(graph, {app, :workspace})
    end

    for {_app, project} <- workspace.projects,
        {dep, _dep_config} <- project.config[:deps] || [],
        node_type = node_type(workspace, dep),
        include_app?(project.app, opts[:ignore]),
        include_app?(dep, opts[:ignore]),
        include_node_type?(node_type, opts[:external]) do
      :digraph.add_vertex(graph, {dep, node_type})
      :digraph.add_edge(graph, {project.app, :workspace}, {dep, node_type})
    end

    graph
  end

  defp include_app?(_app, nil), do: true
  defp include_app?(app, ignore) when is_atom(app), do: include_app?(Atom.to_string(app), ignore)
  defp include_app?(app, ignore) when is_list(ignore), do: app not in ignore

  defp node_type(workspace, app) do
    case Workspace.project?(workspace, app) do
      true -> :workspace
      false -> :external
    end
  end

  defp include_node_type?(:workspace, _flag), do: true
  defp include_node_type?(:external, true), do: true
  defp include_node_type?(_type, _flag), do: false

  @doc """
  Return the source projects of the workspace

  Notice that the project names are returned, you can use `Workspace.project/2`
  to map them back into projects.
  """
  @spec source_projects(workspace :: Workspace.t()) :: [atom()]
  def source_projects(workspace) do
    with_digraph(workspace, fn graph ->
      graph
      |> :digraph.source_vertices()
      |> Enum.map(fn {app, _type} -> app end)
    end)
  end

  @doc """
  Return the sink projects of the workspace

  Notice that the project names are returned, you can use `Workspace.project/2`
  to map them back into projects.
  """
  @spec sink_projects(workspace :: Workspace.t()) :: [atom()]
  def sink_projects(workspace) do
    with_digraph(workspace, fn graph ->
      graph
      |> :digraph.sink_vertices()
      |> Enum.map(fn {app, _type} -> app end)
    end)
  end

  @doc """
  Get the affected workspace's projects given the changed projects

  Notice that the project names are returned, you can use `Workspace.project/2`
  to map them back into projects.
  """
  @spec affected(workspace :: Workspace.t(), projects :: [atom()]) :: [atom()]
  def affected(workspace, projects) do
    projects = Enum.map(projects, fn project -> {project, :workspace} end)

    with_digraph(workspace, fn graph ->
      :digraph_utils.reaching_neighbours(projects, graph)
      |> Enum.concat(projects)
      |> Enum.uniq()
      |> Enum.map(fn {app, _type} -> app end)
    end)
  end
end
