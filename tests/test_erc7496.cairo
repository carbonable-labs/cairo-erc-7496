use starknet::ContractAddress;
use starknet::contract_address_const;
use snforge_std::{
    declare, ContractClassTrait, start_prank, CheatTarget, spy_events, SpyOn, EventSpy,
    EventAssertions
};
use openzeppelin::utils::serde::SerializedAppend;
use cairo_erc_7496::erc7496::interface::IERC7496_ID;
use cairo_erc_7496::presets::erc721_dynamic_traits::{
    ERC721DynamicTraits, IERC721DynamicTraitsMixinDispatcherTrait,
    IERC721DynamicTraitsMixinDispatcher
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

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

fn METADATA_URI() -> ByteArray {
    "https://example.com/labels.json"
}

fn setup() -> (IERC721DynamicTraitsMixinDispatcher, ContractAddress) {
    let contract = declare("ERC721DynamicTraits");
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    let contract_address = contract.deploy(@calldata).unwrap();
    let token = IERC721DynamicTraitsMixinDispatcher { contract_address };
    (token, contract_address)
}

#[test]
fn test_supports_interface_id() {
    let (token, _contract_address) = setup();
    assert!(token.supports_interface(IERC7496_ID));
}

#[test]
fn test_returns_value_set() {
    let (token, contract_address) = setup();
    let mut spy = spy_events(SpyOn::One(contract_address));
    let key = 'testKey';
    let value = 'foo';
    let token_id = 12345;
    token.mint(RECIPIENT(), token_id);
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
#[should_panic(expected: 'Caller is not the owner')]
fn test_only_owner_can_set_values() {
    let (token, contract_address) = setup();
    start_prank(CheatTarget::One(contract_address), OTHER());
    token.set_trait(0, 'test', 'test');
}

#[test]
#[should_panic(expected: 'ERC7496: trait value unchanged')]
fn test_set_trait_unchanged() {
    let (token, _contract_address) = setup();
    let key = 'testKey';
    let value = 'foo';
    let token_id = 1;
    token.mint(RECIPIENT(), token_id);
    token.set_trait(token_id, key, value);
    token.set_trait(token_id, key, value);
}

#[test]
fn test_get_trait_values() {
    let (token, _contract_address) = setup();
    let key1 = 'testKeyOne';
    let key2 = 'testKeyTwo';
    let value1 = 'foo';
    let value2 = 'bar';
    let token_id = 1;
    token.mint(RECIPIENT(), token_id);
    token.set_trait(token_id, key1, value1);
    token.set_trait(token_id, key2, value2);
    let values = token.get_trait_values(token_id, array![key1, key2].span());
    assert_eq!(*values.at(0), value1);
    assert_eq!(*values.at(1), value2);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_get_and_set_trait_metadata_uri() {
    let (token, contract_address) = setup();
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
    token.set_trait_metadata_uri(METADATA_URI());
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_set_trait_value_nonexistent_token() {
    let (token, _contract_address) = setup();
    let key = 'testKey';
    let value = 1;
    let token_id = 1;
    token.set_trait(token_id, key, value);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_get_trait_value_nonexistent_token() {
    let (token, _contract_address) = setup();
    let key = 'testKey';
    let token_id = 1;
    token.get_trait_value(token_id, key);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_get_trait_values_nonexistent_token() {
    let (token, _contract_address) = setup();
    let key = 'testKey';
    let token_id = 1;
    token.get_trait_values(token_id, array![key].span());
}

#[test]
fn test_get_trait_value_default_zero_value() {
    let (token, _contract_address) = setup();
    let key = 'testKey';
    let token_id = 1;
    token.mint(RECIPIENT(), token_id);
    let value = token.get_trait_value(token_id, key);
    assert_eq!(value, 0);
    let values = token.get_trait_values(token_id, array![key].span());
    assert_eq!(*values.at(0), 0);
}
