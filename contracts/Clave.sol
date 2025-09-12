// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Clave is ERC721, ERC721Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct Organizer {
        string company;
        string cnpj;
        string email;
        string phone;
        address wallet;
    }

    Organizer public currentOrganizer;

    event OrganizerChanged(
        string indexed cnpj,
        uint256 indexed season,
        string company,
        string email,
        string phone,
        address wallet,   
        uint256 timestamp
    );

    constructor(address defaultAdmin, address minter) ERC721("Clave", "CLV") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
    }

    function setCurrentOrganizer(
        string memory company,
        string memory cnpj,
        string memory email,
        string memory phone,
        address wallet,
        uint256 season
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(company).length > 0, "Empresa obrigatoria");
        require(bytes(cnpj).length == 14, "CNPJ deve ter 14 caracteres");
        require(bytes(email).length > 0, "Email obrigatorio");
        require(bytes(phone).length >= 8, "Telefone obrigatorio");
        require(wallet != address(0), "Endereco wallet obrigatorio");

        currentOrganizer = Organizer({
            company: company,
            cnpj: cnpj,
            email: email,
            phone: phone,
            wallet: wallet
        });
        emit OrganizerChanged(
            cnpj,
            season,
            company,
            email,
            phone,
            wallet,
            block.timestamp
        );
    }

    function getCurrentOrganizer() public view returns (Organizer memory) {
        require(currentOrganizer.wallet != address(0), "Sem organizador atual");
        return currentOrganizer;
    }

    function safeMint(
        address to,
        uint256 tokenId
    ) public onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
