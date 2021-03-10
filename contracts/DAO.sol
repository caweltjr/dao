// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
/**
 * DAO contract needs to:
 * 0. Attract a group of investors
 * 1. Collect the investors money (ether)
 * 2. Keep track of the investors contributions(the invested ether) with shares
 * 3. Allow the investors to transfer shares
 * 4. allow investment proposals to be created and voted on
 * 5. execute successful investment proposals (i.e send money)
 */
contract DAO {
    struct Proposal{
        uint id;
        string name;
        uint amount;
        address payable recipient; // will get paid if his proposal is executed
        uint votes;
        uint end;
        bool executed;
    }
    // create a list of potential investors - true if they invested
    mapping (address => bool) public investors;
    // keep track of how much each investor has invested - call the money 'shares'
    mapping (address => uint) public shares;
    // total shares to be used in voting on proposals to get weight of a specific investor
    uint public totalShares;
    // total amount of available funds;
    uint public availableFunds;
    // fund is closed-end; investors can only invest(contribute) once in the beginning; keep track of end date
    uint public contributionEnd; // just using instructors variable names
    // keep mapping of proposals
    mapping (uint => Proposal) public proposals;
    uint public nextProposalId;
    mapping (address => mapping(uint => bool)) public votes;
    uint public voteTime;
    uint public quorum; // percent of votes for a proposal
    address public admin;

    modifier onlyInvestors {
        require(investors[msg.sender] == true, "only investors can perform this function");
        _;
    }
    modifier onlyAdmin {
        require( msg.sender == admin, "only admin can perform this function");
        _;
    }
    constructor(
        uint contributionTime,
        uint _voteTime,
        uint _quorum)
    public {
        require(_quorum > 0 && _quorum < 100, 'quorum must be between 0 and 100');
        contributionEnd = now + contributionTime;
        voteTime = _voteTime;
        quorum = _quorum;
        admin = msg.sender;
    }
    // called when someone other than admin sends this contract ether
    function () payable external {
        availableFunds += msg.value;
    }
    // payable function
    function contribute() external payable {
        require(block.timestamp < contributionEnd, "cannot contribute after contributionEnd");
        investors[msg.sender] = true; // shouldn't we check he's in the list first?
        shares[msg.sender] = msg.value;
        totalShares += msg.value;
        availableFunds += msg.value;
    }
    function redeemShares(uint amount) external{
        require(shares[msg.sender] >= amount, "Investor does not have this amount of shares");
        require(availableFunds >= amount, "amount is too large; not enough available funds");
        shares[msg.sender] -= amount;
        availableFunds -= amount;
        msg.sender.transfer(amount);
    }
    function transferShares(uint amount, address to) external{
        require(shares[msg.sender] >= amount, "Investor does not have this amount of shares");
        shares[msg.sender] -= amount;
        shares[to] += amount;
        investors[to] = true;
    }
    function createProposal(string calldata name, uint amount, address payable recipient) onlyInvestors() external{
        require(availableFunds >= amount, "amount too big");
        proposals[nextProposalId] = Proposal(
            nextProposalId,
            name,
            amount,
            recipient,
            0, // not votest
            block.timestamp + voteTime,
            false
        );
        availableFunds -= amount;
        nextProposalId++;
    }
    function vote(uint proposalId) onlyInvestors() external{
        require(votes[msg.sender][proposalId] == false, "investor can only vote once for a proposal");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.end, "can only vote until the proposal end date");
        votes[msg.sender][proposalId] = true;
        proposal.votes += shares[msg.sender];//effectively gives voting power based on number of shares

    }
    // only the admin can actually execute a proposal, which transfers ether to the proposal recipient
    function executeProposal(uint proposalId) onlyAdmin() external{
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.end, "cannot execute proposal before end date");
        require(proposal.executed == false, "cannot execute proposal already executed");
        require((proposal.votes / totalShares) * 100 >= quorum, "cannot execute proposal with votes # below quorum" );
        _transferEther(proposal.amount, proposal.recipient);
    }
    function withdrawEther(uint amount, address payable to) onlyAdmin() external {
        _transferEther(amount, to);
    }
    function _transferEther(uint amount, address payable to) internal {
        require(availableFunds <= amount, "not enough available funds");
        availableFunds -= amount;
        to.transfer(amount);
    }
}
