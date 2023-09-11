use starknet::{
    ContractAddress, get_caller_address, Felt252TryIntoContractAddress, contract_address_const
};
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};

use satoru::event::event_emitter::{IEventEmitterDispatcher, IEventEmitterDispatcherTrait};
use satoru::exchange::withdrawal_handler::{IWithdrawalHandlerDispatcher, IWithdrawalHandlerDispatcherTrait};
use satoru::withdrawal::withdrawal_vault::{IWithdrawalVaultDispatcher, IWithdrawalVaultDispatcherTrait};
use satoru::data::data_store::{IDataStoreDispatcher, IDataStoreDispatcherTrait};
use satoru::data::keys::{
    claim_fee_amount_key, claim_ui_fee_amount_key, claim_ui_fee_amount_for_account_key
};
use satoru::role::role_store::{IRoleStoreDispatcher, IRoleStoreDispatcherTrait};
use satoru::role::role;
use satoru::withdrawal::withdrawal_utils::CreateWithdrawalParams;

#[test]
fn test_create_withdrawal() {
    let (caller_address, data_store, event_emitter, withdrawal_handler) = setup();

    let account: ContractAddress = 0x123.try_into().unwrap();
    let receiver: ContractAddress = 0x234.try_into().unwrap();
    let ui_fee_receiver: ContractAddress = 0x345.try_into().unwrap();
    let market: ContractAddress = 0x456.try_into().unwrap();

    let params: CreateWithdrawalParams = CreateWithdrawalParams {
            receiver,
            callback_contract: receiver,
            /// The ui fee receiver.
            ui_fee_receiver,
            /// The market on which the withdrawal will be executed.
            market,
            /// The swap path for the long token
            long_token_swap_path: Default::default(),
            /// The short token swap path
            short_token_swap_path: Default::default(),
            /// The minimum amount of long tokens that must be withdrawn.
            min_long_token_amount: Default::default(),
            /// The minimum amount of short tokens that must be withdrawn.
            min_short_token_amount: Default::default(),
            /// Whether the native token should be unwrapped when executing the withdrawal.
            should_unwrap_native_token: Default::default(),
            /// The execution fee for the withdrawal.
            execution_fee: Default::default(),
            /// The gas limit for calling the callback contract.
            callback_gas_limit: Default::default(),
    };

    withdrawal_handler.create_withdrawal(account, params);
}

fn deploy_withdrawal_handler(data_store_address: ContractAddress, role_store_address: ContractAddress,
                                        event_emitter_address: ContractAddress, withdrawal_vault_address: ContractAddress,
                                        oracle_address: ContractAddress) -> ContractAddress {
    let contract = declare('WithdrawalHandler');
    let constructor_calldata = array![
        data_store_address.into(), role_store_address.into(), event_emitter_address.into(), withdrawal_vault_address.into(), oracle_address.into()
    ];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_oracle(oracle_store_address: ContractAddress, role_store_address: ContractAddress) -> ContractAddress {
    let contract = declare('Oracle');
    let constructor_calldata = array![role_store_address.into(), oracle_store_address.into()];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_oracle_store(role_store_address: ContractAddress, event_emitter_address: ContractAddress) -> ContractAddress {
    let contract = declare('OracleStore');
    let constructor_calldata = array![role_store_address.into(), event_emitter_address.into()];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_withdrawal_vault(strict_bank_address: ContractAddress) -> ContractAddress {
    let contract = declare('WithdrawalVault');
    let constructor_calldata = array![strict_bank_address.into()];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_strict_bank(data_store_address: ContractAddress, role_store_address: ContractAddress) -> ContractAddress {
    let contract = declare('StrictBank');
    let constructor_calldata = array![data_store_address.into(), role_store_address.into()];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_data_store(role_store_address: ContractAddress) -> ContractAddress {
    let contract = declare('DataStore');
    let constructor_calldata = array![role_store_address.into()];
    contract.deploy(@constructor_calldata).unwrap()
}

fn deploy_role_store() -> ContractAddress {
    let contract = declare('RoleStore');
    contract.deploy(@array![]).unwrap()
}

fn deploy_event_emitter() -> ContractAddress {
    let contract = declare('EventEmitter');
    contract.deploy(@array![]).unwrap()
}

fn setup() -> (
    ContractAddress, IDataStoreDispatcher, IEventEmitterDispatcher, IWithdrawalHandlerDispatcher
) {
    let caller_address: ContractAddress = 0x101.try_into().unwrap();
    let role_store_address = deploy_role_store();
    let role_store = IRoleStoreDispatcher { contract_address: role_store_address };
    let data_store_address = deploy_data_store(role_store_address);
    let data_store = IDataStoreDispatcher { contract_address: data_store_address };
    let event_emitter_address = deploy_event_emitter();
    let event_emitter = IEventEmitterDispatcher { contract_address: event_emitter_address };
    let strict_bank_address = deploy_strict_bank(data_store_address, role_store_address);
    let withdrawal_vault_address = deploy_withdrawal_vault(strict_bank_address);
    let oracle_store_address = deploy_oracle_store(role_store_address, event_emitter_address);
    let oracle_address = deploy_oracle(oracle_store_address, role_store_address);
    let withdrawal_handler_address = deploy_withdrawal_handler(
        data_store_address, role_store_address, event_emitter_address, withdrawal_vault_address, oracle_address
    );
    let fee_handler = IFeeHandlerDispatcher { contract_address: fee_handler_address };
    start_prank(role_store_address, caller_address);
    role_store.grant_role(caller_address, role::CONTROLLER);
    start_prank(data_store_address, caller_address);
    (caller_address, data_store, event_emitter, fee_handler)
}