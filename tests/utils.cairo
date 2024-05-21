use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, BASE_URI};
use cairo_erc_7496::presets::erc721_dynamic_traits::{
    IERC721DynamicTraitsMixinDispatcher, IERC721DynamicTraitsMixinSafeDispatcher
};

#[derive(Copy, Drop)]
pub struct DynamicTraitsTest {
    pub contract_address: ContractAddress,
    pub token: IERC721DynamicTraitsMixinDispatcher,
    pub token_safe: IERC721DynamicTraitsMixinSafeDispatcher,
}

#[generate_trait]
pub impl DynamicTraitsTestImpl of DynamicTraitsTestTrait {
    fn setup() -> DynamicTraitsTest {
        let contract = declare("ERC721DynamicTraits").unwrap();
        let mut calldata: Array<felt252> = array![];
        calldata.append_serde(NAME());
        calldata.append_serde(SYMBOL());
        calldata.append_serde(BASE_URI());
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        let token = IERC721DynamicTraitsMixinDispatcher { contract_address };
        let token_safe = IERC721DynamicTraitsMixinSafeDispatcher { contract_address };
        DynamicTraitsTest { contract_address, token, token_safe }
    }
}
