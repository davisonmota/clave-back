// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Clave is ERC721, ERC721Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_TABLES = 150;

    enum Session {
        Jkafe,
        Baiuca,
        Vitelo,
        EstradaReal,
        ButequinDaQuitanda,
        Raccon,
        Taberna,
        BristoVesperata,
        PastelECia,
        EsquinaDaQuitanda
    }

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
        bool active;
    }

    struct TableInfo {
        uint256 tableId;
        uint256 purchaseId;
        uint256 presentationId;
        uint256 purchaseTimestamp;
        bool checkedIn;
        Session session;
    }

    Organizer public currentOrganizer;

    mapping(uint256 => uint256) public presentationsPerSeasonCount;
    mapping(uint256 => uint256[]) public seasonPresentationIds;
    mapping(uint256 => Presentation) public presentations;
    mapping(uint256 => Session) public tokenSession;

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
        uint256 tablePrice
    );

    event PresentationUpdated(
        uint256 indexed id,
        uint256 date,
        uint256 startTime,
        uint256 endTime,
        uint256 tablePrice
    );

    event TablePurchased(
        uint256 purchaseId,
        uint256 presentationId,
        uint256 tableId,
        address buyer,
        Session session
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
        uint256 _tablePrice
    ) public onlyOrganizer {
        require(_date > block.timestamp, "A data deve ser no futuro");
        require(
            _startTime < _endTime,
            "Inicio do evento deve ser ante do termino"
        );
        require(_tablePrice > 0, "O preco da mesa deve ser maior que zero");
        require(_season >= 2025, "Temporada invalida");

        uint256 presentationNumberOfSeason = presentationsPerSeasonCount[
            _season
        ]++;
        uint256 presentationId = _season * 10000 + presentationNumberOfSeason;

        presentations[presentationId] = Presentation({
            id: presentationId,
            date: _date,
            startTime: _startTime,
            endTime: _endTime,
            season: _season,
            tablePrice: _tablePrice,
            active: true
        });
        seasonPresentationIds[_season].push(presentationId);

        emit PresentationCreated(
            presentationId,
            _date,
            _startTime,
            _endTime,
            _season,
            _tablePrice
        );
    }

    function getPresentationsBySeason(
        uint256 season
    ) public view returns (Presentation[] memory) {
        uint256[] memory presentationIds = seasonPresentationIds[season];
        Presentation[] memory seasonPresentations = new Presentation[](
            presentationIds.length
        );

        for (uint i = 0; i < presentationIds.length; i++) {
            seasonPresentations[i] = presentations[presentationIds[i]];
        }

        return seasonPresentations;
    }

    function getPresentationById(
        uint256 presentationId
    ) public view returns (Presentation memory) {
        return presentations[presentationId];
    }

    function updatePresentation(
        uint256 _presentationId,
        uint256 _date,
        uint256 _season,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tablePrice
    ) public onlyOrganizer {
        Presentation storage presentation = presentations[_presentationId];

        require(presentation.id != 0, "Apresentacao nao encontrada");
        require(
            presentation.active,
            "Apenas apresentacoes ativas podem ser alteradas"
        );
        require(
            presentation.date > block.timestamp,
            "Nao pode alterar apresentacao que ja ocorreu"
        );
        require(_date > block.timestamp, "A nova data deve ser no futuro");
        require(
            _season == presentation.season,
            "Nao e permitido alterar a temporada da apresentacao"
        );
        require(
            _startTime < _endTime,
            "Inicio do evento deve ser ante do termino"
        );
        require(_tablePrice > 0, "O preco da mesa deve ser maior que zero");

        presentation.date = _date;
        presentation.startTime = _startTime;
        presentation.endTime = _endTime;
        presentation.tablePrice = _tablePrice;

        emit PresentationUpdated(
            _presentationId,
            _date,
            _startTime,
            _endTime,
            _tablePrice
        );
    }

    function purchaseTable(
        uint256 _presentationId,
        uint256 _tableId,
        Session _session
    ) public payable {
        Presentation storage presentation = presentations[_presentationId];
        require(presentation.id != 0, "Apresentacao nao encontrada");
        require(presentation.active, "A apresentacao nao esta ativa");
        require(
            presentationTables[_presentationId][_tableId].purchaseId == 0,
            "A mesa ja foi vendida"
        );
        require(msg.value == presentation.tablePrice, "Preco incorreto");
        require(_tableId > 0 && _tableId <= MAX_TABLES, "Mesa invalida");

        uint256 purchaseId = ++purchaseCount;
        presentationTables[_presentationId][_tableId] = TableInfo({
            tableId: _tableId,
            purchaseId: purchaseId,
            presentationId: _presentationId,
            purchaseTimestamp: block.timestamp,
            checkedIn: false,
            session: _session
        });

        emit TablePurchased(
            purchaseId,
            _presentationId,
            _tableId,
            msg.sender,
            _session
        );
    }

    function safeMint(
        address to,
        uint256 tokenId,
        Session session
    ) public onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
        tokenSession[tokenId] = session;
    }

    function getSessionByTokenId(
        uint256 tokenId
    ) public view returns (Session) {
        require(ownerOf(tokenId) != address(0), "Token nao existe");
        return tokenSession[tokenId];
    }

    function getTablesForPresentation(
        uint256 presentationId
    ) public view returns (TableInfo[] memory) {
        TableInfo[] memory tables = new TableInfo[](MAX_TABLES);
        for (uint i = 0; i < MAX_TABLES; i++) {
            tables[i] = presentationTables[presentationId][i + 1];
        }
        return tables;
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
