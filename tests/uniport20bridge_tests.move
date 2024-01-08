#[test_only]
module uniport::uniport20bridge_tests {
    use std::signer::{Self, address_of};
    use aptos_framework::account::{Self};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin::{Self};
    use std::string::{Self, String};

    use uniport::uniport20bridge::{Self};
    use uniport::uniport20factory::{SATS, ORDI, RATS, ETHS, ETHI, ETHR, BNBS, BSCI, BSCR};

    fun init_pool(sender: &signer) {
        uniport20bridge::init_for_testing(sender);
    }

    fun set_fee_manager(sender: &signer, fee_manager: address) {
        uniport20bridge::setFeeManager(sender, fee_manager);
    }

    fun set_support_chains(sender: &signer, chainId: u128, support: bool) {
        uniport20bridge::setSupportChains(sender, chainId, support);
    }

    fun set_fee(sender: &signer, chainId: u128, fee: u64) {
        uniport20bridge::setFee(sender, chainId, fee);
    }

    fun create_uniport20<T>(sender: &signer, name: String, symbol: String, decimals: u8) {
        uniport20bridge::createUNIPORT20<T>(
            sender,
            name,
            symbol,
            decimals
        );
    }

    fun mint_uniport20<T>(sender: &signer, amount: u64, srcChainId: u128, txId: String, to: address) {
        uniport20bridge::mint<T>(
            sender,
            to,
            amount,
            srcChainId,
            txId
        );
    }

    fun burn_uniport20<T>(sender: &signer, amount: u64, dstChainId: u128, receiver: String) {
        uniport20bridge::burn<T>(
            sender,
            amount,
            dstChainId,
            receiver
        );
    }

    fun withdraw(sender: &signer, receiver: address) {
        uniport20bridge::withdraw(
            sender,
            receiver
        );
    }

    #[test(aptos=@aptos_framework)]
    fun test_init_pool_(aptos: &signer) {
        setup();

        let uniport = account::create_account_for_test(@uniport);
        init_pool(&uniport);

        let fee_manager = account::create_account_for_test(@fee_manager);
        let owner = account::create_account_for_test(@owner);
        let multi_sig = account::create_account_for_test(@multi_sig);
        let user1 = account::create_account_for_test(@user1);
        let user2 = account::create_account_for_test(@user2);

        setup_user_coins(&uniport);
        setup_user_coins(&fee_manager);
        setup_user_coins(&owner);
        setup_user_coins(&multi_sig);
        setup_user_coins(&user1);
        setup_user_coins(&user2);

        let amount = 100000000;
        aptos_coin::mint(aptos, address_of(&user1), amount * 10);

        set_fee_manager(&uniport, signer::address_of(&fee_manager));

        let btc_chainId = 0;
        let btc_fee = 10000;

        let eth_chainId = 1;
        let eth_fee = 20000;

        let bsc_chainId = 56;
        let bsc_fee = 30000;

        set_support_chains(&uniport, btc_chainId, true);
        set_support_chains(&uniport, eth_chainId, true);
        set_support_chains(&uniport, bsc_chainId, true);

        set_fee(&fee_manager, btc_chainId, btc_fee);
        set_fee(&fee_manager, eth_chainId, eth_fee);
        set_fee(&fee_manager, bsc_chainId, bsc_fee);

        // BTC
        create_uniport20<SATS>(&uniport, string::utf8(b"SATS"), string::utf8(b"SATS"), 8);
        create_uniport20<ORDI>(&uniport, string::utf8(b"ORDI"), string::utf8(b"ORDI"), 8);
        create_uniport20<RATS>(&uniport, string::utf8(b"RATS"), string::utf8(b"RATS"), 8);

        // ETH
        create_uniport20<ETHS>(&uniport, string::utf8(b"ETHS"), string::utf8(b"ETHS"), 8);
        create_uniport20<ETHI>(&uniport, string::utf8(b"ETHI"), string::utf8(b"ETHI"), 8);
        create_uniport20<ETHR>(&uniport, string::utf8(b"ETHR"), string::utf8(b"ETHR"), 8);

        // BSC
        create_uniport20<BNBS>(&uniport, string::utf8(b"BNBS"), string::utf8(b"BNBS"), 8);
        create_uniport20<BSCI>(&uniport, string::utf8(b"BSCI"), string::utf8(b"BSCI"), 8);
        create_uniport20<BSCR>(&uniport, string::utf8(b"BSCR"), string::utf8(b"BSCR"), 8);

        // BTC
        let sats_amount = 1_000_000_000;
        let ordi_amount = 2_000_000_000;
        let rats_amount = 3_000_000_000;

        // ETH
        let eths_amount = 4_000_000_000;
        let ethi_amount = 5_000_000_000;
        let ethr_amount = 6_000_000_000;

        // BSC
        let bnbs_amount = 7_000_000_000;
        let bsci_amount = 8_000_000_000;
        let bscr_amount = 9_000_000_000;

        uniport20bridge::transfer_msign(&uniport, &multi_sig);

        // BTC
        mint_uniport20<SATS>(&multi_sig, sats_amount, btc_chainId, string::utf8(b"sats_txid"), signer::address_of(&user1));
        mint_uniport20<ORDI>(&multi_sig, ordi_amount, btc_chainId, string::utf8(b"ordi_txId"), signer::address_of(&user1));
        mint_uniport20<RATS>(&multi_sig, rats_amount, btc_chainId, string::utf8(b"rats_txId"), signer::address_of(&user1));

        // ETH
        mint_uniport20<ETHS>(&multi_sig, eths_amount, eth_chainId, string::utf8(b"eths_txId"), signer::address_of(&user1));
        mint_uniport20<ETHI>(&multi_sig, ethi_amount, eth_chainId, string::utf8(b"ethi_txId"), signer::address_of(&user1));
        mint_uniport20<ETHR>(&multi_sig, ethr_amount, eth_chainId, string::utf8(b"ethr_txId"), signer::address_of(&user1));
        // BSC
        mint_uniport20<BNBS>(&multi_sig, bnbs_amount, bsc_chainId, string::utf8(b"bnbs_txId"), signer::address_of(&user1));
        mint_uniport20<BSCI>(&multi_sig, bsci_amount, bsc_chainId, string::utf8(b"bsci_txId"), signer::address_of(&user1));
        mint_uniport20<BSCR>(&multi_sig, bscr_amount, bsc_chainId, string::utf8(b"bscr_txId"), signer::address_of(&user1));

        burn_uniport20<SATS>(&user1, sats_amount, btc_chainId, string::utf8(b"11111111111111111"));
        burn_uniport20<ORDI>(&user1, ordi_amount, btc_chainId, string::utf8(b"22222222222222222"));
        burn_uniport20<RATS>(&user1, rats_amount, btc_chainId, string::utf8(b"33333333333333333"));

        burn_uniport20<ETHS>(&user1, eths_amount, eth_chainId, string::utf8(b"44444444444444444"));
        burn_uniport20<ETHI>(&user1, ethi_amount, eth_chainId, string::utf8(b"55555555555555555"));
        burn_uniport20<ETHR>(&user1, ethr_amount, eth_chainId, string::utf8(b"66666666666666666"));

        burn_uniport20<BNBS>(&user1, bnbs_amount, bsc_chainId, string::utf8(b"77777777777777777"));
        burn_uniport20<BSCI>(&user1, bsci_amount, bsc_chainId, string::utf8(b"88888888888888888"));
        burn_uniport20<BSCR>(&user1, bscr_amount, bsc_chainId, string::utf8(b"99999999999999999"));


        withdraw(&uniport, address_of(&user2));
        assert!(coin::balance<AptosCoin>(address_of(&user2)) == (btc_fee + eth_fee + bsc_fee) * 3, 0);
   }

    // utilities
    public fun setup_user_coins(s: &signer) {
        setup_user_coin<AptosCoin>(s);

        setup_user_coin<SATS>(s);
        setup_user_coin<ORDI>(s);
        setup_user_coin<RATS>(s);

        setup_user_coin<ETHS>(s);
        setup_user_coin<ETHI>(s);
        setup_user_coin<ETHR>(s);
        
        setup_user_coin<BNBS>(s);
        setup_user_coin<BSCI>(s);
        setup_user_coin<BSCR>(s);
    }

    public fun setup_user_coin<T>(user: &signer) {
        coin::register<T>(user);
    }

    public fun setup() {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(
            &account::create_signer_with_capability(
                &account::create_test_signer_cap(@aptos_framework)));
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);        
    }
}
