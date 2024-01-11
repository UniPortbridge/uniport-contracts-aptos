module uniport::uniport20bridge {
    use std::signer::{Self};
    use std::string::{String};
    use std::option::{Self, Option};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{type_name};
    use aptos_framework::account::{new_event_handle};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::aptos_coin::{AptosCoin};

    struct BridgeAdminCap has key, store {}
    struct MultiSigAdminCap has key, store {}

    struct Pool<phantom T> has key {
        burn_cap: coin::BurnCapability<T>,
        freeze_cap: coin::FreezeCapability<T>,
        mint_cap: coin::MintCapability<T>,
    }

    struct BridgeState has key {
        feeManager: Option<address>,
        aptos: Coin<AptosCoin>,
        chainFees: Table<u128, u64>,
        supportChains: Table<u128, bool>,
        used: Table<String, bool>, // hex string
        symbolContracts: Table<String, String>, // hex string

        feeManagerChanged: EventHandle<FeeManagerChanged>,
        feeChanged: EventHandle<FeeChanged>,
        supportChainsChanged: EventHandle<SupportChainsChanged>,
        uniport20Created: EventHandle<UNIPORT20Created>,
        bridgeMinted: EventHandle<BridgeMinted>,
        bridgeBurned: EventHandle<BridgeBurned>,
    }

    /// Errors
    const E_NOT_UNIPORT: u64 = 0;
    const E_ZERO_AMOUNT: u64 = 1;
    const E_CHAIN_ID_NOT_SUPPORT: u64 = 2;
    const E_CHAIN_ID_FEE_NOT_SET: u64 = 3;
    const E_TXID_ALREADY_USED: u64 = 4;
    const E_NOT_FEE_MANAGER: u64 = 7;
    const E_DUPLICATE_SYMBOL: u64 = 8;
    const E_NOT_MULTI_SIGNER: u64 = 9;
    const E_SAME_ADDRESS: u64 = 11;

    const ZERO_ADDRESS: address = @0x0;

    /// Events
    struct FeeManagerChanged has drop, store {
        oldFeeManager: address,
        newFeeManager: address,
    }

    struct FeeChanged has drop, store {
        chainId: u128,
        oldFee: u64,
        newFee: u64,
    }

    struct SupportChainsChanged has drop, store {
        chainId: u128,
        preSupport: bool,
        support: bool,
    }

    struct UNIPORT20Created has drop, store {
        sender: address,
        uniport20: String,
        symbol: String,
    }

    struct BridgeMinted has drop, store {
        token: String,
        to: address,
        amount: u64,
        srcChainId: u128,
        txId: String,
    }

    struct BridgeBurned has drop, store {
        token: String,
        from: address,
        amount: u64,
        chainId: u128,
        fee: u64,
        receiver: String,
    }

    fun init_module(sender: &signer) {
        assert!(signer::address_of(sender) == @uniport, E_NOT_UNIPORT);
        move_to(sender, BridgeAdminCap {});
        move_to(sender, MultiSigAdminCap {});
        move_to(sender, BridgeState {
            feeManager: option::none<address>(),
            aptos: coin::zero<AptosCoin>(),
            chainFees: table::new(),
            supportChains: table::new(),
            used: table::new(),
            symbolContracts: table::new(),

            feeManagerChanged: new_event_handle(sender),
            feeChanged: new_event_handle(sender),
            supportChainsChanged: new_event_handle(sender),
            uniport20Created: new_event_handle(sender),
            bridgeMinted: new_event_handle(sender),
            bridgeBurned: new_event_handle(sender),
        });
    }

    public entry fun createUNIPORT20<T>(sender: &signer, name: String, symbol: String, decimals: u8)
        acquires BridgeState
    {
        assert!(exists<BridgeAdminCap>(signer::address_of(sender)), E_NOT_UNIPORT);
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<T>(
            sender,
            name,
            symbol,
            decimals,
            true, // monitor_supply
        );

        move_to(sender, Pool {
            burn_cap,
            freeze_cap,
            mint_cap,
        });

        let sym = symbol;
        assert!(!table::contains(&bridgeState.symbolContracts, sym), E_DUPLICATE_SYMBOL);
        table::add(&mut bridgeState.symbolContracts, sym, type_name<T>());

        event::emit_event(&mut bridgeState.uniport20Created, UNIPORT20Created {
            sender: signer::address_of(sender),
            uniport20: type_name<T>(),
            symbol: sym,
        });
    }

    public entry fun transfer(from: &signer, to: &signer)
        acquires BridgeAdminCap
    {
        assert!(signer::address_of(from) != signer::address_of(to), E_SAME_ADDRESS);
        let cap = move_from<BridgeAdminCap>(signer::address_of(from));
        move_to(to, cap);
    }

    public entry fun transfer_msign(from: &signer, to: &signer)
        acquires MultiSigAdminCap
    {
        assert!(signer::address_of(from) != signer::address_of(to), E_SAME_ADDRESS);
        let cap = move_from<MultiSigAdminCap>(signer::address_of(from));
        move_to(to, cap);
    }

    public entry fun mint<T>(sender: &signer, to: address, amount: u64, srcChainId: u128, txId: String)
        acquires Pool, BridgeState
    {
        assert!(exists<MultiSigAdminCap>(signer::address_of(sender)), E_NOT_MULTI_SIGNER);
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);
        let pool = borrow_global_mut<Pool<T>>(@uniport);
        
        assert!(table::contains(&bridgeState.supportChains, srcChainId), E_CHAIN_ID_NOT_SUPPORT);
        assert!(table::contains(&bridgeState.chainFees, srcChainId), E_CHAIN_ID_FEE_NOT_SET);
        assert!(!table::contains(&bridgeState.used, txId), E_TXID_ALREADY_USED);
        table::add(&mut bridgeState.used, txId, true);
        let coin_minted = coin::mint<T>(amount, &pool.mint_cap);
        coin::deposit<T>(to, coin_minted);

        event::emit_event(&mut bridgeState.bridgeMinted, BridgeMinted {
            token: type_name<T>(),
            to,
            amount,
            srcChainId,
            txId,
        });
    }
 
    public entry fun burn<T>(sender: &signer, burnAmount: u64, dstChainId: u128, receiver: String)
        acquires Pool, BridgeState
    {
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);
        assert!(table::contains(&bridgeState.supportChains, dstChainId), E_CHAIN_ID_NOT_SUPPORT);
        assert!(table::contains(&bridgeState.chainFees, dstChainId), E_CHAIN_ID_FEE_NOT_SET);

        assert!(burnAmount > 0, E_ZERO_AMOUNT);
        let fee = *table::borrow(&bridgeState.chainFees, dstChainId);

        let coin = coin::withdraw<T>(sender, burnAmount);
        let aptos = coin::withdraw<AptosCoin>(sender, fee);
        let pool = borrow_global_mut<Pool<T>>(@uniport);
        coin::merge(&mut bridgeState.aptos, aptos);
        coin::burn(coin, &pool.burn_cap);

        event::emit_event(&mut bridgeState.bridgeBurned, BridgeBurned {
            token: type_name<T>(),
            from: signer::address_of(sender),
            amount: burnAmount,
            chainId: dstChainId,
            fee,
            receiver,
        });
    }

    public entry fun register_coin<T>(sender: &signer) {
        coin::register<T>(sender);
    }

    public entry fun withdraw(sender: &signer, to: address)
        acquires BridgeState
    {
        assert!(exists<BridgeAdminCap>(signer::address_of(sender)), E_NOT_UNIPORT);
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);

        let bal = coin::extract_all(&mut bridgeState.aptos);
        coin::deposit(to, bal);
    }

    public entry fun setFeeManager(sender: &signer, newFeeManager: address)
        acquires BridgeState
    {
        assert!(exists<BridgeAdminCap>(signer::address_of(sender)), E_NOT_UNIPORT);
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);

        let opt = option::swap_or_fill(&mut bridgeState.feeManager, newFeeManager);
        if (option::is_some(&opt)) {
            let oldFeeManager = option::destroy_some(opt);
            event::emit_event(&mut bridgeState.feeManagerChanged, FeeManagerChanged {
                oldFeeManager,
                newFeeManager,
            });
        } else {
            event::emit_event(&mut bridgeState.feeManagerChanged, FeeManagerChanged {
                oldFeeManager: ZERO_ADDRESS,
                newFeeManager,
            });
        };
    }

    public entry fun setFee(sender: &signer, chainId: u128, newFee: u64)
        acquires BridgeState
    {
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);

        let feeManager = *option::borrow(&bridgeState.feeManager);
        assert!(feeManager == signer::address_of(sender), E_NOT_FEE_MANAGER);

        if (table::contains(&bridgeState.chainFees, chainId)) {
            event::emit_event(&mut bridgeState.feeChanged, FeeChanged {
                chainId,
                oldFee: *table::borrow(&bridgeState.chainFees, chainId),
                newFee,
            });
            *table::borrow_mut(&mut bridgeState.chainFees, chainId) = newFee;
        } else {
            table::add(&mut bridgeState.chainFees, chainId, newFee);
            event::emit_event(&mut bridgeState.feeChanged, FeeChanged {
                chainId,
                oldFee: 0,
                newFee,
            });
        };
    }

    public entry fun setSupportChains(sender: &signer, chainId: u128, support: bool)
        acquires BridgeState
    {
        assert!(exists<BridgeAdminCap>(signer::address_of(sender)), E_NOT_UNIPORT);
        let bridgeState = borrow_global_mut<BridgeState>(@uniport);

        if (table::contains(&bridgeState.supportChains, chainId)) {
            event::emit_event(&mut bridgeState.supportChainsChanged, SupportChainsChanged {
                chainId,
                preSupport: *table::borrow(&bridgeState.supportChains, chainId),
                support,
            });
            *table::borrow_mut(&mut bridgeState.supportChains, chainId) = support;
        } else {
            table::add(&mut bridgeState.supportChains, chainId, support);
            event::emit_event(&mut bridgeState.supportChainsChanged, SupportChainsChanged {
                chainId,
                preSupport: false,
                support,
            });
        };
    }

    #[test_only]
    public fun init_for_testing(uniport: &signer) {
        init_module(uniport);
    }
}
