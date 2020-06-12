defmodule MiniRepo.APIRouter do
  @moduledoc false
  use Plug.Router
  require Logger

  plug Plug.Parsers,
    parsers: [MiniRepo.HexErlangParser],
    pass: ["*/*"]

  plug :match
  plug :dispatch, builder_opts()

  def call(conn, opts) do
    conn =
      Plug.Conn.put_private(conn, :mini_repo, %{
        url: opts[:url],
        repositories: opts[:repositories]
      })

    super(conn, opts)
  end

  post "/api/repos/:repo/publish" do
    {:ok, tarball, conn} = read_tarball(conn)
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.publish(repo, tarball) do
      :ok ->
        body = %{"url" => opts[:url]}
        body = :erlang.term_to_binary(body)

        conn
        |> put_resp_content_type("application/vnd.hex+erlang")
        |> send_resp(200, body)

      {:error, _} = error ->
        body = :erlang.term_to_binary(error)

        conn
        |> put_resp_content_type("application/vnd.hex+erlang")
        |> send_resp(400, body)
    end
  end

  delete "/api/repos/:repo/packages/:name/releases/:version" do
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.revert(repo, name, version) do
      :ok -> send_resp(conn, 204, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.retire(repo, name, version, conn.body_params) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  delete "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.unretire(repo, name, version) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/docs" do
    repo = repo!(conn, repo)
    {:ok, docs_tarball, conn} = read_tarball(conn)

    case MiniRepo.Repository.Server.publish_docs(repo, name, version, docs_tarball) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

# TODO convertire tutto per puntare ad S3
# posso usare MiniRepo.Store.fetch(key, options, state) -> {:ok, body}/{:error, :not_found} per controllare se c'è tutto

  get "/repos/hexpm_mirror/packages/:name" do
    Logger.debug("#{name}")
    MiniRepo.Mirror.ServerOnDemand.fetch_package_if_not_exist(name)

    with {:ok, data_path} <- get_data_dir(:hexpm_mirror),
        package_path <- "#{data_path}/repos/hexpm_mirror/packages/#{name}",
        true <- MiniRepo.Store.S3.exists?(package_path),
        {:ok, body} <- MiniRepo.Store.S3.fetch(package_path) do
        
        # contents =
        # @s3_bucket
        # |> ExAws.S3.list_objects()
        # |> ExAws.stream!()

        # S3.list_objects |> ExAws.request! #=> %{body: [list, of, objects]}
        # S3.list_objects |> ExAws.stream! |> Enum.to_list #=> [list, of, objects]


        # HTTPDownloader.stream!( url_to_my_s3_file )
        # > Enum.each(fn chunk-> send_chunk_to_client(client_conn, chunk) end)

        send_resp(conn, 200, body)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/hexpm_mirror/tarballs/:tarball" do
    tb =
      String.split(tarball, "-")

      name = Enum.at(tb, 0)
      version = 
      Enum.at(tb, 1)
      |> String.replace(".tar", "")

    MiniRepo.Mirror.ServerOnDemand.fetch_tarball_if_not_exist(name, version)

    with {:ok, data_path} <- get_data_dir(:hexpm_mirror),
         tarball_path <- "#{data_path}/repos/hexpm_mirror/tarballs/#{tarball}",
         true <- File.exists?(tarball_path) do
      send_file(conn, 200, tarball_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/packages/:name" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         package_path <-"#{data_path}/repos/#{repo}/packages/#{name}",
         true <- File.exists?(package_path) do
      send_file(conn, 200, package_path)
    else
      _ ->
        send_resp(conn, 404, "name: #{name}, repo: #{repo} not found")
    end
  end

  get "/repos/:repo/tarballs/:tarball" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         tarball_path <- "#{data_path}/repos/#{repo}/tarballs/#{tarball}",
         true <- File.exists?(tarball_path) do
      send_file(conn, 200, tarball_path)
    else
      _ ->
        send_resp(conn, 404, "repo: #{repo}, tarbal: #{tarball} not found")
    end
  end

  get "/repos/:repo/names/" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         names_path <- "#{data_path}/repos/#{repo}/names/",
         true <- File.exists?(names_path) do
      send_file(conn, 200, names_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/versions/" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         versions_path <- "#{data_path}/repos/#{repo}/versions/",
         true <- File.exists?(versions_path) do
      send_file(conn, 200, versions_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/docs/:tarball" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         docs_path <- "#{data_path}/repos/#{repo}/docs/#{tarball}",
         true <- File.exists?(docs_path) do
      send_file(conn, 200, docs_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end


  match _ do
    send_resp(conn, 404, "not found")
  end

  defp repo!(conn, repo) do
    allowed_repos = conn.private.mini_repo.repositories

    if repo in allowed_repos do
      String.to_existing_atom(repo)
    else
      raise ArgumentError,
            "#{inspect(repo)} is not allowed, allowed repos: #{inspect(allowed_repos)}"
    end
  end

  def get_data_dir(repo) do
    repo =
      Application.get_env(:mini_repo, :repositories)
      |> Enum.filter(fn {key, _} -> key == repo end)

    case repo do
      [] ->
        {:error, "Repo not found"}

      [{_key, opts}] ->
        {_, [root: dir]} = opts[:store]
        {:ok, dir}

      _ ->
        {:error, "Duplicate repos defined"}
    end
  end

  defp read_tarball(conn, tarball \\ <<>>) do
    case Plug.Conn.read_body(conn) do
      {:more, partial, conn} ->
        read_tarball(conn, tarball <> partial)

      {:ok, body, conn} ->
        {:ok, tarball <> body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
