defmodule MiniRepo.Store.Local do
  @moduledoc """
  Local file system storage.

  Options:

  * `:root` - the root directory to store files in.

    It can be either a string containing a file system path
    or a tuple containing the application name and the directory
    to store files in.

    To make the path independent from the starting directory
    it's recommended to use either relative file system path
    or the tuple.
  """

  @behaviour MiniRepo.Store

  require Logger
  defstruct [:root]

  @impl true
  def put(path, value) do
    path = path(path)
    Logger.debug(inspect({__MODULE__, :put, path}))
    File.mkdir_p!(Path.dirname(path))
    File.write(path, value)
  end

  @impl true
  def fetch(path) do
    path = path(path)
    Logger.debug(inspect({__MODULE__, :fetch, path}))

    case File.read(path) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, :enoent} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  @impl true
  def exists?(path) do
    path = path(path)
    Logger.debug(inspect({__MODULE__, :exists, path}))
    File.exists?(path)
  end

  @impl true
  def delete(path) do
    path = path(path)

    case File.rm(path) do
      :ok ->
        :ok

      {:error, :enoent} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  defp path(path) do
    root =
      case path_root() do
        {app, path} when is_atom(app) and is_binary(path) ->
          Path.join(Application.app_dir(app), path)

        binary when is_binary(binary) ->
          binary
      end

    Path.join([root | List.wrap(path)])
  end

  defp path_root(), do: Application.get_env(:store, :root)
end
