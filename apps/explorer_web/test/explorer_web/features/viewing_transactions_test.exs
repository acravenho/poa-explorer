defmodule ExplorerWeb.ViewingTransactionsTest do
  @moduledoc false

  use ExplorerWeb.FeatureCase, async: true

  alias Explorer.Chain.Wei
  alias ExplorerWeb.{AddressPage, HomePage, TransactionListPage, TransactionLogsPage, TransactionPage}

  setup do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    4
    |> insert_list(:transaction)
    |> with_block()

    pending = insert(:transaction, block_hash: nil, gas: 5891, index: nil)

    lincoln = insert(:address)
    taft = insert(:address)

    transaction =
      :transaction
      |> insert(
        value: Wei.from(Decimal.new(5656), :ether),
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        input: "0x000012",
        nonce: 99045,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        from_address_hash: taft.hash,
        to_address_hash: lincoln.hash
      )
      |> with_block(block, gas_used: Decimal.new(1_230_000_000_000_123_000), status: :ok)

    insert(:log, address_hash: lincoln.hash, index: 0, transaction_hash: transaction.hash)

    # From Lincoln to Taft.
    txn_from_lincoln =
      :transaction
      |> insert(from_address_hash: lincoln.hash, to_address_hash: taft.hash)
      |> with_block(block)

    internal = insert(:internal_transaction, index: 0, transaction_hash: transaction.hash)

    {:ok,
     %{
       pending: pending,
       internal: internal,
       lincoln: lincoln,
       taft: taft,
       transaction: transaction,
       txn_from_lincoln: txn_from_lincoln
     }}
  end

  test "search for transactions", %{session: session} do
    transaction = insert(:transaction, input: "0x736f636b73")

    session
    |> HomePage.visit_page()
    |> HomePage.search(to_string(transaction.hash))
    |> assert_has(TransactionPage.detail_hash(transaction))
  end

  describe "viewing transaction lists" do
    test "transactions on the home page", %{session: session} do
      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))
    end

    test "viewing the default transactions tab", %{session: session, transaction: transaction, pending: pending} do
      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.transaction(transaction))
      |> refute_has(TransactionListPage.transaction(pending))
    end

    test "viewing the pending tab", %{pending: pending, session: session} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_pending()
      |> assert_has(TransactionListPage.transaction(pending))

      # |> click(css(".transactions__link", text: to_string(pending.hash)))
    end
  end

  describe "viewing a transaction page" do
    test "can navigate to transaction show from list page", %{session: session, transaction: transaction} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_transaction(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can see a transaction's details", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can view a transaction's logs", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> TransactionPage.click_logs()
      |> assert_has(TransactionLogsPage.logs(count: 1))
    end

    test "can visit an address from the transaction logs page", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction
    } do
      session
      |> TransactionLogsPage.visit_page(transaction)
      |> TransactionLogsPage.click_address(lincoln)
      |> assert_has(AddressPage.detail_hash(lincoln))
    end
  end
end
