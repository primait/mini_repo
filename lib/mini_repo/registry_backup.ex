defmodule MiniRepo.RegistryBackup do
  @moduledoc false

  @manifest_vsn 1

  def save(repository) do
    contents = %{
      manifest_vsn: @manifest_vsn,
      registry: repository.registry
    }

    store_put(backup_path(repository), :erlang.term_to_binary(contents))
  end

  def load(repository) do
    registry =
      case store_fetch(backup_path(repository)) do
        {:ok, contents} ->
          manifest_vsn = @manifest_vsn

          %{manifest_vsn: ^manifest_vsn, registry: registry} = :erlang.binary_to_term(contents)

          registry

        {:error, :not_found} ->
          %{}
      end

    %{repository | registry: registry}
  end

  defp backup_path(repository) do
    repository.name <> ".bin"
  end

  defp store_put(name, content) do
    :ok = MiniRepo.Store.S3.put(name, content)
  end

  defp store_fetch(name) do
    MiniRepo.Store.S3.fetch(name)
  end
end
