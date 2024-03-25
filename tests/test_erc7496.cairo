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
    ERC721DynamicTraits, IERC721DynamicTraitsMixinDispatcherTrait,
    IERC721DynamicTraitsMixinDispatcher, IERC721DynamicTraitsMixinSafeDispatcherTrait,
    IERC721DynamicTraitsMixinSafeDispatcher
};

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
    let key = 'testKey';
    let value = 'foo';
    let token_id = 12345;
    token.mint(test_address(), token_id);
    let mut spy = spy_events(SpyOn::One(contract_address));
    token.set_trait(token_id, key, value);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC721DynamicTraits::ERC7496Component::Event::TraitUpdated(
                        ERC721DynamicTraits::ERC7496Component::TraitUpdated {
                            trait_key: key, token_id, trait_value: value
                        }
                    )
                )
            ]
        );
    assert_eq!(token.get_trait_value(token_id, key), value);
}

#[test]
fn test_only_owner_can_set_values() {
    let (contract_address, _token, token_safe) = setup();
    start_prank(CheatTarget::One(contract_address), OTHER());
    match token_safe.set_trait(0, 'test', 'test') {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), OwnableComponent::Errors::NOT_OWNER);
        }
    }
}

#[test]
fn test_set_trait_unchanged() {
    let (_contract_address, token, token_safe) = setup();
    let key = 'testKey';
    let value = 'foo';
    let token_id = 1;
    token.mint(test_address(), token_id);
    token.set_trait(token_id, key, value);
    match token_safe.set_trait(token_id, key, value) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC7496Component::Errors::TRAIT_VALUE_UNCHANGED);
        }
    }
}

#[test]
fn test_get_trait_values() {
    let (_contract_address, token, _token_safe) = setup();
    let key1 = 'testKeyOne';
    let key2 = 'testKeyTwo';
    let value1 = 'foo';
    let value2 = 'bar';
    let token_id = 1;
    token.mint(test_address(), token_id);
    token.set_trait(token_id, key1, value1);
    token.set_trait(token_id, key2, value2);
    let values = token.get_trait_values(token_id, array![key1, key2].span());
    assert_eq!(*values.at(0), value1);
    assert_eq!(*values.at(1), value2);
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
                    ERC721DynamicTraits::ERC7496Component::Event::TraitMetadataURIUpdated(
                        ERC721DynamicTraits::ERC7496Component::TraitMetadataURIUpdated {}
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
    let key = 'testKey';
    let value = 1;
    let token_id = 1;
    match token_safe.set_trait(token_id, key, value) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match token_safe.get_trait_value(token_id, key) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match token_safe.get_trait_values(token_id, array![key].span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
}

#[test]
fn test_get_trait_value_default_zero_value() {
    let (_contract_address, token, _token_safe) = setup();
    let key = 'testKey';
    let token_id = 1;
    token.mint(test_address(), token_id);
    let value = token.get_trait_value(token_id, key);
    assert_eq!(value, 0);
    let values = token.get_trait_values(token_id, array![key].span());
    assert_eq!(*values.at(0), 0);
}
