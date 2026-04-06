// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Clave is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControlEnumerable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MAX_TABLES = 150;
    uint256 public feeAmount;
    uint256 public withdrawalDelay;
    uint256 public accumulatedFees;
    string public baseURI;

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
        address checkedInBy;
        uint256 checkInTimestamp;
        Session session;
        address buyer;
    }

    Organizer public currentOrganizer;

    mapping(uint256 => uint256) public presentationsPerSeasonCount;
    mapping(uint256 => uint256[]) public seasonPresentationIds;
    mapping(uint256 => Presentation) public presentations;
    mapping(uint256 => Session) public tokenSession;

    uint256 public purchaseCount;
    mapping(uint256 => mapping(uint256 => TableInfo)) public presentationTables;
    mapping(uint256 => uint256) public presentationFunds;

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
        uint256 indexed tokenId,
        uint256 purchaseId,
        uint256 presentationId,
        uint256 tableId,
        address buyer,
        Session session,
        uint256 price,
        string tokenURI,
        uint256 timestamp
    );

    event TableCheckedIn(
        uint256 indexed tokenId,
        uint256 presentationId,
        uint256 tableId,
        address indexed operator,
        uint256 timestamp
    );

    event WithdrawalDelayUpdated(uint256 newDelay, address indexed changedBy);

    event FundsWithdrawn(
        uint256 indexed presentationId,
        address indexed to,
        uint256 amount
    );

    event FeesWithdrawn(address indexed to, uint256 amount);

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
        feeAmount = 0.0005 ether;
        withdrawalDelay = 3 days;
    }

    function _generateTokenId(
        uint256 _presentationId,
        uint256 _tableId
    ) internal pure returns (uint256) {
        return _presentationId * 10000 + _tableId;
    }

    function setWithdrawalDelay(
        uint256 _newDelay
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newDelay > 0, "Prazo de saque invalido");
        withdrawalDelay = _newDelay;
        emit WithdrawalDelayUpdated(_newDelay, msg.sender);
    }

    function setBaseURI(
        string memory _newBaseURI
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _newBaseURI;
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
        require(
            wallet != currentOrganizer.wallet,
            "Organizer is already set to this address"
        );

        // Limpa TODOS os operadores existentes.
        uint256 operatorCount = getRoleMemberCount(OPERATOR_ROLE);
        for (uint256 i = operatorCount; i > 0; i--) {
            address operator = getRoleMember(OPERATOR_ROLE, i - 1);
            _revokeRole(OPERATOR_ROLE, operator);
        }

        // Define o novo organizador
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

    function addOperator(address operatorAddress) public onlyOrganizer {
        require(
            operatorAddress != address(0),
            "Operator address cannot be zero"
        );
        _grantRole(OPERATOR_ROLE, operatorAddress);
    }

    function removeOperator(address operatorAddress) public onlyOrganizer {
        require(
            operatorAddress != address(0),
            "Operator address cannot be zero"
        );
        _revokeRole(OPERATOR_ROLE, operatorAddress);
    }

    function getCheckInMessage(
        uint256 _presentationId,
        uint256 _tableId
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "Eu autorizo o check-in para a mesa ",
                    Strings.toString(_tableId),
                    " da apresentacao ",
                    Strings.toString(_presentationId),
                    " no contrato ",
                    Strings.toHexString(uint160(address(this)), 20),
                    " na chain ID ",
                    Strings.toString(block.chainid)
                )
            );
    }

    function _getEthSignedCheckInHash(
        uint256 _presentationId,
        uint256 _tableId
    ) internal view returns (bytes32) {
        string memory message = getCheckInMessage(_presentationId, _tableId);
        return MessageHashUtils.toEthSignedMessageHash(bytes(message));
    }

    function checkIn(
        uint256 _presentationId,
        uint256 _tableId,
        bytes memory signature
    ) public {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Not an operator");

        Presentation storage presentation = presentations[_presentationId];
        require(presentation.id != 0, "Apresentacao nao encontrada");

        require(
            block.timestamp >= presentation.startTime - 1 hours,
            "Check-in ainda nao esta aberto"
        );
        require(
            block.timestamp <= presentation.endTime,
            "Check-in ja esta fechado"
        );

        TableInfo storage table = presentationTables[_presentationId][_tableId];
        require(table.purchaseId != 0, "Mesa nao foi vendida");
        require(!table.checkedIn, "Check-in ja foi realizado");

        uint256 tokenId = _generateTokenId(_presentationId, _tableId);
        address owner = ownerOf(tokenId);
        require(owner != address(0), "Ingresso (NFT) invalido");

        bytes32 messageHash = _getEthSignedCheckInHash(
            _presentationId,
            _tableId
        );
        address signerAddress = ECDSA.recover(messageHash, signature);

        require(
            signerAddress == owner,
            "Assinatura invalida ou nao pertence ao dono do ingresso"
        );

        table.checkedIn = true;
        table.checkedInBy = msg.sender;
        table.checkInTimestamp = block.timestamp;

        emit TableCheckedIn(
            tokenId,
            _presentationId,
            _tableId,
            msg.sender,
            block.timestamp
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
        require(
            msg.value == presentation.tablePrice + feeAmount,
            "Preco incorreto"
        );
        require(_tableId > 0 && _tableId <= MAX_TABLES, "Mesa invalida");

        presentationFunds[_presentationId] += presentation.tablePrice;
        accumulatedFees += feeAmount;

        uint256 purchaseId = ++purchaseCount;
        presentationTables[_presentationId][_tableId] = TableInfo({
            tableId: _tableId,
            purchaseId: purchaseId,
            presentationId: _presentationId,
            purchaseTimestamp: block.timestamp,
            checkedIn: false,
            checkedInBy: address(0),
            checkInTimestamp: 0,
            session: _session,
            buyer: msg.sender
        });

        uint256 tokenId = _generateTokenId(_presentationId, _tableId);
        string memory newTokenURI = string(
            abi.encodePacked(baseURI, Strings.toString(tokenId))
        );
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, newTokenURI);
        tokenSession[tokenId] = _session;

        emit TablePurchased(
            tokenId,
            purchaseId,
            _presentationId,
            _tableId,
            msg.sender,
            _session,
            presentation.tablePrice,
            newTokenURI,
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

    function setFeeAmount(
        uint256 _newFeeAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeAmount = _newFeeAmount;
    }

    function withdrawFees() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = accumulatedFees;
        require(amount > 0, "Nao ha taxas para sacar");
        accumulatedFees = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Saque de taxas falhou");

        emit FeesWithdrawn(msg.sender, amount);
    }

    function withdrawFunds(uint256 _presentationId) public onlyOrganizer {
        Presentation storage presentation = presentations[_presentationId];
        require(presentation.id != 0, "Apresentacao nao encontrada");
        require(
            block.timestamp > presentation.endTime + withdrawalDelay,
            "Saque disponivel apenas apos o periodo de bloqueio"
        );

        uint256 amount = presentationFunds[_presentationId];
        require(amount > 0, "Nao ha fundos para sacar");

        // A atualização do saldo é feita antes da chamada externa para prevenir ataques de reentrada (Checks-Effects-Interactions pattern).
        // Se a transferência falhar, a transação inteira será revertida, garantindo que os fundos não sejam perdidos.
        presentationFunds[_presentationId] = 0;

        (bool success, ) = payable(currentOrganizer.wallet).call{value: amount}(
            ""
        );
        require(success, "Falha na transferencia para o organizador");
        emit FundsWithdrawn(_presentationId, currentOrganizer.wallet, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721,
            ERC721Enumerable,
            ERC721URIStorage,
            AccessControlEnumerable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
