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

    struct Presentation {
        uint256 id;
        uint256 date;
        uint256 startTime;
        uint256 endTime;
        uint256 season;
        uint256 tablePrice;
        uint256 maxTables;
        bool active;
    }

    struct TableInfo {
        uint256 tableId;
        uint256 purchaseId;
        uint256 presentationId;
        uint256 purchaseTimestamp;
        bool checkedIn;
    }

    Organizer public currentOrganizer;

    uint256 public presentationCount;
    mapping(uint256 => Presentation) public presentations;

    uint256 public purchaseCount;
    mapping(uint256 => mapping(uint256 => TableInfo)) public presentationTables;

    event OrganizerChanged(
        string indexed cnpj,
        uint256 indexed season,
        string company,
        string email,
        string phone,
        address wallet,
        uint256 timestamp
    );

    event PresentationCreated(
        uint256 indexed id,
        uint256 date,
        uint256 startTime,
        uint256 endTime,
        uint256 indexed season,
        uint256 tablePrice,
        uint256 maxTables
    );

    event TablePurchased(
        uint256 purchaseId,
        uint256 presentationId,
        uint256 tableId,
        address buyer
    );

    modifier onlyOrganizer() {
        require(
            msg.sender == currentOrganizer.wallet,
            "Not the current organizer"
        );
        _;
    }

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

    function createPresentation(
        uint256 _date,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _season,
        uint256 _tablePrice,
        uint256 _maxTables
    ) public onlyOrganizer {
        require(_date > block.timestamp, "A data deve ser no futuro");
        require(
            _startTime < _endTime,
            "Inicio do evento deve ser ante do termino"
        );
        require(_tablePrice > 0, "O preco da mesa deve ser maior que zero");
        require(_maxTables > 0, "Numero de mesa deve ser maior que zero");
        require(_season >= 2025, "Temporada invalida");

        presentationCount++;
        presentations[presentationCount] = Presentation({
            id: presentationCount,
            date: _date,
            startTime: _startTime,
            endTime: _endTime,
            season: _season,
            tablePrice: _tablePrice,
            maxTables: _maxTables,
            active: true
        });
        emit PresentationCreated(
            presentationCount,
            _date,
            _startTime,
            _endTime,
            _season,
            _tablePrice,
            _maxTables
        );
    }

    function purchaseTable(
        uint256 _presentationId,
        uint256 _tableId
    ) public payable {
        Presentation storage presentation = presentations[_presentationId];
        require(presentation.id != 0, "Apresentacao nao encontrada");
        require(presentation.active, "A apresentacao nao esta ativa");
        require(
            presentationTables[_presentationId][_tableId].purchaseId == 0,
            "A mesa ja foi vendida"
        );
        require(msg.value == presentation.tablePrice, "Preco incorreto");

        uint256 purchaseId = ++purchaseCount;
        presentationTables[_presentationId][_tableId] = TableInfo({
            tableId: _tableId,
            purchaseId: purchaseId,
            presentationId: _presentationId,
            purchaseTimestamp: block.timestamp,
            checkedIn: false
        });

        emit TablePurchased(purchaseId, _presentationId, _tableId, msg.sender);
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
