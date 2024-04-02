use core::panic_with_felt252;
use starknet::ContractAddress;
use starknet::contract_address_const;
use snforge_std::{
    declare, ContractClassTrait, test_address, start_prank, CheatTarget, spy_events, SpyOn,
    EventSpy, EventAssertions
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::token::erc721::ERC721Component;
use cairo_erc_7496::erc7496::interface::IERC7496_ID;
use cairo_erc_7496::erc7496::erc7496::ERC7496Component;
use cairo_erc_7496::presets::erc721_dynamic_traits::{
    IERC721DynamicTraitsMixinDispatcherTrait, IERC721DynamicTraitsMixinDispatcher,
    IERC721DynamicTraitsMixinSafeDispatcherTrait, IERC721DynamicTraitsMixinSafeDispatcher
};

const TOKEN_ID: u256 = 1;
const TOKEN_ID_2: u256 = 2;
const TRAIT_KEY: felt252 = 'key';
const TRAIT_KEY_2: felt252 = 'key2';
const TRAIT_VALUE: felt252 = 'value1';
const TRAIT_VALUE_2: felt252 = 'value2';

fn NAME() -> ByteArray {
    "ERC721DynamicTraits"
}

fn SYMBOL() -> ByteArray {
    "ERC721DT"
}

fn BASE_URI() -> ByteArray {
    "https://example.com"
}

fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

fn METADATA_URI() -> ByteArray {
    "https://example.com/labels.json"
}

fn setup() -> (
    ContractAddress, IERC721DynamicTraitsMixinDispatcher, IERC721DynamicTraitsMixinSafeDispatcher
) {
    let contract = declare("ERC721DynamicTraits");
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(test_address());
    calldata.append_serde(array![TOKEN_ID].span());
    let contract_address = contract.deploy(@calldata).unwrap();
    let token = IERC721DynamicTraitsMixinDispatcher { contract_address };
    let token_safe = IERC721DynamicTraitsMixinSafeDispatcher { contract_address };
    (contract_address, token, token_safe)
}

#[test]
fn test_supports_interface_id() {
    let (_contract_address, token, _token_safe) = setup();
    assert!(token.supports_interface(IERC7496_ID));
}

#[test]
fn test_returns_value_set() {
    let (contract_address, token, _token_safe) = setup();
    let mut spy = spy_events(SpyOn::One(contract_address));
    token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC7496Component::Event::TraitUpdated(
                        ERC7496Component::TraitUpdated {
                            trait_key: TRAIT_KEY, token_id: TOKEN_ID, trait_value: TRAIT_VALUE
                        }
                    )
                )
            ]
        );
    assert_eq!(token.safe_get_trait_value(TOKEN_ID, TRAIT_KEY), TRAIT_VALUE);
}

#[test]
fn test_only_owner_can_set_values() {
    let (contract_address, _token, token_safe) = setup();
    start_prank(CheatTarget::One(contract_address), OTHER());
    match token_safe.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), OwnableComponent::Errors::NOT_OWNER);
        }
    }
}

#[test]
fn test_set_trait_unchanged() {
    let (_contract_address, token, token_safe) = setup();
    token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    match token_safe.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC7496Component::Errors::TRAIT_VALUE_UNCHANGED);
        }
    }
}

#[test]
fn test_get_trait_values() {
    let (_contract_address, token, _token_safe) = setup();
    token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    token.set_trait(TOKEN_ID, TRAIT_KEY_2, TRAIT_VALUE_2);
    let values = token.safe_get_trait_values(TOKEN_ID, array![TRAIT_KEY, TRAIT_KEY_2].span());
    assert_eq!(*values.at(0), TRAIT_VALUE);
    assert_eq!(*values.at(1), TRAIT_VALUE_2);
}

#[test]
fn test_get_and_set_trait_metadata_uri() {
    let (contract_address, token, token_safe) = setup();
    let mut spy = spy_events(SpyOn::One(contract_address));
    token.set_trait_metadata_uri(METADATA_URI());
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC7496Component::Event::TraitMetadataURIUpdated(
                        ERC7496Component::TraitMetadataURIUpdated {}
                    )
                )
            ]
        );
    assert_eq!(token.get_trait_metadata_uri(), METADATA_URI());
    start_prank(CheatTarget::One(contract_address), OTHER());
    match token_safe.set_trait_metadata_uri(METADATA_URI()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), OwnableComponent::Errors::NOT_OWNER);
        }
    }
}

#[test]
fn test_get_and_set_trait_value_nonexistent_token() {
    let (_contract_address, _token, token_safe) = setup();
    match token_safe.set_trait(TOKEN_ID_2, TRAIT_KEY, TRAIT_VALUE) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match token_safe.safe_get_trait_value(TOKEN_ID_2, TRAIT_KEY) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match token_safe.safe_get_trait_values(TOKEN_ID_2, array![TRAIT_KEY].span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
}

#[test]
fn test_get_trait_value_default_zero_value() {
    let (_contract_address, token, _token_safe) = setup();
    let value = token.safe_get_trait_value(TOKEN_ID, TRAIT_KEY);
    assert_eq!(value, 0);
    let values = token.safe_get_trait_values(TOKEN_ID, array![TRAIT_KEY].span());
    assert_eq!(*values.at(0), 0);
}
