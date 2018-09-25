defmodule DB do
  @mydb :my_db
  @doc """
  Starts the DB
  """
  def start do
    Process.register(spawn(__MODULE__, :loop, [[]]), :my_db)
  end

  def terminate(state) do
    IO.inspect "Last known state: #{state}"
    IO.inspect "terminating...."
  end

  @doc """
  Stops the DB

  Example

    iex> DB.start
    iex> :my_db in Process.registered()
    true
    iex> DB.stop
    iex> :my_db in Process.registered()
    false
  """
  def stop do
    send(@mydb, {:stop, self()})
    receive do
      _reply ->
        :ok
    end
  end

  def write(key, element), do: call(@mydb, {:write, key, element})
  def delete(key), do: call(@mydb, {:delete, key})
  def read(key), do: call(@mydb, {:read, key})
  def match(element), do: call(@mydb, {:match, element})

  # message handlers, modifies loop data
  def handle_msg({:write, key, element}, loop_data), do: {:ok, [{key, element} | loop_data]}

  def handle_msg({:delete, key}, loop_data) do
    case Keyword.has_key?(loop_data, key) do
      true ->
        new_loop_data =
          loop_data
          |> Enum.reduce([], fn {k, v}, acc ->
            case k == key do
              true -> acc
              false -> [{k, v} | acc]
            end
          end)

        {:ok, new_loop_data}

      false ->
        {{:error, :instance}, loop_data}
    end
  end

  def handle_msg({:read, key}, loop_data) do
    case Keyword.get(loop_data, key) do
      nil -> {{:error, :instance}, loop_data}
      element -> {:ok, element}
    end
  end

  def handle_msg({:match, element}, loop_data) do
    reply =
      loop_data
      |> Enum.reduce([], fn {k, v}, acc ->
        case v == element do
          true ->
            [k | acc]
          false ->
            acc
        end
      end)
    {reply, loop_data}
  end

  def call(name, message) do
    send(name, {:request, self(), message})
    receive do
      {:reply, reply} -> reply
    end
  end

  def reply(to, message), do: send(to, {:reply, message})

  def loop(state) do
    receive do
      {:request, from, message} ->
        {reply, new_state} = handle_msg(message, state)
        reply(from, reply)
        loop(new_state)
      {:stop, from} ->
        reply(from, terminate(state))
        Process.exit(self(), :kill)
    end
  end
end
