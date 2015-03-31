alias Harakiri.Worker
alias Harakiri.ActionGroup
alias TestHelpers, as: TH

defmodule HarakiriTest do
  use ExUnit.Case, async: false

  test "adds, gets, and clears state" do
    # call it with no state
    :ok = Worker.clear
    # put some state
    data = %ActionGroup{paths: [], app: :bogus, action: :stop}
    :ok = Worker.add data
    # the second time it's not duplicated
    :duplicate = Worker.add data
    # check it's there, only one
    assert [data] == Worker.state
    # clear and chek it's gone
    :ok = Worker.clear
    assert [] == Worker.state
  end

  test "fires given action when touching one of given files" do
    # setup ActionGroup
    :os.cmd 'touch /tmp/bogus' # create it
    :ok = Worker.add %ActionGroup{paths: ["/tmp/bogus"], app: :bogus, action: :stop}
    :ok = Worker.add %{paths: ["/tmp/bogus2"], app: :bogus2, action: :stop}

    # now it's looping, but no hits
    TH.wait_for fn ->
      %ActionGroup{metadata: md} = Worker.state |> List.first
      md[:loops] > 0 and md[:hits] == 0
    end

    # touch file
    :os.cmd 'touch /tmp/bogus'

    # now it's been fired once
    TH.wait_for fn ->
      %ActionGroup{metadata: md} = Worker.state |> List.first
      md[:loops] > 0 and md[:hits] == 1
    end
  end

  test "stop does not crash" do
    ag = %{paths: ["/tmp/bogus"], app: :bogus, action: :stop} |> Worker.digest_data
    :ok = Worker.fire :stop, ag
  end

  test "reload does not crash" do
    ag = %{paths: ["/tmp/bogus"], app: :bogus, action: :reload} |> Worker.digest_data
    :ok = Worker.fire :reload, ag
  end

  test "The supervisor ancestor owns the ETS table" do
    # the table exists
    refute :ets.info(:harakiri_table) == :undefined
    # get the owner
    owner = :ets.info(:harakiri_table)[:owner]
    # get the supervisor ancestor
    info = Process.whereis(Harakiri.Supervisor) |> Process.info
    sup_ancestor = info[:dictionary][:"$ancestors"] |> List.first
    assert owner == sup_ancestor
  end

end
