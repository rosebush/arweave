-module(ar_multi_dir).

-include_lib("arweave/include/ar_config.hrl").
-include_lib("arweave/include/ar_data_sync.hrl").

-export([test/0, read_dir_cfg/1,get_read_filename/1,get_write_filename/1,have_valid_free_space/0]).

test() ->
    {ok, Config} = application:get_env(arweave, config),
    io:format("Hello world!~n").

read_dir_cfg(Filepath) ->
    case file:consult(Filepath) of
        {ok,Result} ->
            Result;
        {_,_} ->
            []
    end.

get_read_filename(Components) ->
    case application:get_env(arweave, config) of
        {ok, Config} ->
            find_dir(Components,Config#config.chunk_directories);
        _ ->
            find_dir(Components,[])
    end.

get_write_filename(Components) ->
    TryReadFile = get_read_filename(Components),
    case filelib:is_file(TryReadFile) of
        true -> TryReadFile;
        false ->
            case application:get_env(arweave, config) of
                {ok, Config} ->
                    get_best_dir(Components,Config#config.chunk_directories);
                _ ->
                    get_best_dir(Components,[])
            end
    end.

get_best_dir([DataDir,ChunkDir,Filename],[First | Others]) ->
    case get_dir_free_size(First) > ?DISK_DATA_BUFFER_SIZE of
        true ->
            filename:join([First,Filename]);
        false ->
            get_best_dir([DataDir,ChunkDir,Filename],Others)
    end;
get_best_dir([DataDir,ChunkDir,Filename],[]) ->
    filename:join([DataDir,ChunkDir,Filename]).

have_valid_free_space() ->
    case application:get_env(arweave, config) of
        {ok, Config} ->
            valid_free_space_dir(Config#config.chunk_directories);
        _ ->
            false
    end.

valid_free_space_dir([Dir,Others]) ->
    case get_dir_free_size(Dir) > ?DISK_DATA_BUFFER_SIZE of
        true ->
            true;
        false ->
            valid_free_space_dir(Others)
    end;
valid_free_space_dir([]) ->
    false.


get_dir_free_size(Dir) ->
	{ok, Config} = application:get_env(arweave, config),
	{_, KByteSize, CapacityKByteSize} = ar_storage:get_disk_data(Dir),
	case Config#config.disk_space of
		undefined ->
			CapacityKByteSize * 1024;
		Limit ->
			max(0, Limit - (KByteSize - CapacityKByteSize) * 1024)
	end.


find_dir([DataDir,ChunkDir,Filename], [Dir | Others]) ->
    Filepath = filename:join(Dir,Filename),
    case filelib:is_file(Filepath) of
        true ->
            Filepath;
        false ->
            find_dir([DataDir,ChunkDir,Filename],Others)
    end;
find_dir([DataDir,ChunkDir,Filename], []) ->
    filename:join([DataDir,ChunkDir,Filename]).
    