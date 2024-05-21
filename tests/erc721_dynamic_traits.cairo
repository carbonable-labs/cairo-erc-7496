use core::panic_with_felt252;
use snforge_std::{
    test_address, start_prank, CheatTarget, spy_events, SpyOn, EventSpy, EventAssertions
};
use openzeppelin::tests::utils::constants::{TOKEN_ID, TOKEN_ID_2, OTHER, BASE_URI_2};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::token::erc721::ERC721Component;
use cairo_erc_7496::erc7496::interface::IERC7496_ID;
use cairo_erc_7496::erc7496::erc7496::ERC7496Component;
use cairo_erc_7496::presets::erc721_dynamic_traits::{
    IERC721DynamicTraitsMixinDispatcherTrait, IERC721DynamicTraitsMixinSafeDispatcherTrait,
};
use super::utils::DynamicTraitsTestTrait;

const TRAIT_KEY: felt252 = 'key1';
const TRAIT_KEY_2: felt252 = 'key2';
const TRAIT_VALUE: felt252 = 'value1';
const TRAIT_VALUE_2: felt252 = 'value2';

#[test]
fn test_supports_interface_id() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    assert!(dynamic_traits_test.token.supports_interface(IERC7496_ID));
}

#[test]
fn test_returns_value_set() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    dynamic_traits_test.token.mint(test_address(), TOKEN_ID);
    let mut spy = spy_events(SpyOn::One(dynamic_traits_test.contract_address));
    dynamic_traits_test.token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    spy
        .assert_emitted(
            @array![
                (
                    dynamic_traits_test.contract_address,
                    ERC7496Component::Event::TraitUpdated(
                        ERC7496Component::TraitUpdated {
                            trait_key: TRAIT_KEY, token_id: TOKEN_ID, trait_value: TRAIT_VALUE
                        }
                    )
                )
            ]
        );
    assert_eq!(dynamic_traits_test.token.get_trait_value(TOKEN_ID, TRAIT_KEY), TRAIT_VALUE);
}

#[test]
fn test_only_owner_can_set_values() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    start_prank(CheatTarget::One(dynamic_traits_test.contract_address), OTHER());
    match dynamic_traits_test.token_safe.set_trait(0, 'test', 'test') {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), OwnableComponent::Errors::NOT_OWNER);
        }
    }
}

#[test]
fn test_set_trait_unchanged() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    dynamic_traits_test.token.mint(test_address(), TOKEN_ID);
    dynamic_traits_test.token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    match dynamic_traits_test.token_safe.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC7496Component::Errors::TRAIT_VALUE_UNCHANGED);
        }
    }
}

#[test]
fn test_get_trait_values() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    dynamic_traits_test.token.mint(test_address(), TOKEN_ID);
    dynamic_traits_test.token.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE);
    dynamic_traits_test.token.set_trait(TOKEN_ID, TRAIT_KEY_2, TRAIT_VALUE_2);
    let values = dynamic_traits_test
        .token
        .get_trait_values(TOKEN_ID, array![TRAIT_KEY, TRAIT_KEY_2].span());
    assert_eq!(*values.at(0), TRAIT_VALUE);
    assert_eq!(*values.at(1), TRAIT_VALUE_2);
}

#[test]
fn test_get_and_set_trait_metadata_uri() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    let mut spy = spy_events(SpyOn::One(dynamic_traits_test.contract_address));
    dynamic_traits_test.token.set_trait_metadata_uri(BASE_URI_2());
    spy
        .assert_emitted(
            @array![
                (
                    dynamic_traits_test.contract_address,
                    ERC7496Component::Event::TraitMetadataURIUpdated(
                        ERC7496Component::TraitMetadataURIUpdated {}
                    )
                )
            ]
        );
    assert_eq!(dynamic_traits_test.token.get_trait_metadata_uri(), BASE_URI_2());
    start_prank(CheatTarget::One(dynamic_traits_test.contract_address), OTHER());
    match dynamic_traits_test.token_safe.set_trait_metadata_uri(BASE_URI_2()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), OwnableComponent::Errors::NOT_OWNER);
        }
    }
}

#[test]
fn test_get_and_set_trait_value_nonexistent_token() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    match dynamic_traits_test.token_safe.set_trait(TOKEN_ID, TRAIT_KEY, TRAIT_VALUE) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match dynamic_traits_test.token_safe.get_trait_value(TOKEN_ID, TRAIT_KEY) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    match dynamic_traits_test.token_safe.get_trait_values(TOKEN_ID, array![TRAIT_KEY].span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
}

#[test]
fn test_get_trait_value_default_zero_value() {
    let dynamic_traits_test = DynamicTraitsTestTrait::setup();
    dynamic_traits_test.token.mint(test_address(), TOKEN_ID);
    let value = dynamic_traits_test.token.get_trait_value(TOKEN_ID, TRAIT_KEY);
    assert_eq!(value, 0);
    let values = dynamic_traits_test.token.get_trait_values(TOKEN_ID, array![TRAIT_KEY].span());
    assert_eq!(*values.at(0), 0);
}
