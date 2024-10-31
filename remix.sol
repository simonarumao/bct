// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CodingInternshipPlatform {
    address public admin;
    uint256 public nextQuestionId;
    uint256 public nextInternshipId;

    // Role Addresses
    address public manager;
    address public teamLead;
    address public employee;

    struct Question {
        string name;
        uint256 reward;
        bool exists;
    }

    struct Internship {
        string name;
        uint256 cost;
        bool exists;
        uint256 nextWorkId; // Track work IDs for each internship separately
    }

    struct Work {
        uint256 internshipId;
        address student;
        string details;
        bool verified;
        uint256 approvals;
    }

    mapping(uint256 => Question) public questions;
    mapping(uint256 => Internship) public internships;
    mapping(address => uint256) public studentTokens;
    mapping(uint256 => mapping(uint256 => Work)) public workLogs; // Indexed by internshipId, then workId
    mapping(address => mapping(uint256 => bool)) public solvedQuestions;
    mapping(address => mapping(uint256 => bool)) public purchasedInternships;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasApproved; // Approval tracking per internship and work ID
    mapping(uint256 => mapping(uint256 => bool)) public approvedWorks; // Verified status per internship and work ID

    event QuestionAdded(uint256 questionId, string name, uint256 reward);
    event InternshipAdded(uint256 internshipId, string name, uint256 cost);
    event RewardClaimed(address student, uint256 questionId, uint256 reward);
    event InternshipPurchased(address student, uint256 internshipId);
    event WorkSubmitted(uint256 internshipId, uint256 workId, address student);
    event WorkApproved(uint256 internshipId, uint256 workId, address approver);
    event WorkFinalized(uint256 internshipId, uint256 workId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyApprover() {
        require(
            msg.sender == manager || 
            msg.sender == teamLead || 
            msg.sender == employee,
            "Only specific approvers can approve work"
        );
        _;
    }

    constructor(address _manager, address _teamLead, address _employee) {
        admin = msg.sender;
        manager = _manager;
        teamLead = _teamLead;
        employee = _employee;
    }

    function addQuestion(string calldata name, uint256 reward) external onlyAdmin {
        questions[nextQuestionId] = Question(name, reward, true);
        emit QuestionAdded(nextQuestionId, name, reward);
        nextQuestionId++;
    }

    function addInternship(string calldata name, uint256 cost) external onlyAdmin {
        internships[nextInternshipId] = Internship(name, cost, true, 0);
        emit InternshipAdded(nextInternshipId, name, cost);
        nextInternshipId++;
    }

    function claimReward(uint256 questionId) external {
        require(questions[questionId].exists, "Question does not exist");
        require(!solvedQuestions[msg.sender][questionId], "Question already solved by student");

        studentTokens[msg.sender] += questions[questionId].reward;
        solvedQuestions[msg.sender][questionId] = true;
        emit RewardClaimed(msg.sender, questionId, questions[questionId].reward);
    }

    function purchaseInternship(uint256 internshipId) external {
        require(internships[internshipId].exists, "Internship does not exist");
        require(studentTokens[msg.sender] >= internships[internshipId].cost, "Insufficient tokens");
        require(!purchasedInternships[msg.sender][internshipId], "Internship already purchased by student");

        studentTokens[msg.sender] -= internships[internshipId].cost;
        purchasedInternships[msg.sender][internshipId] = true;
        emit InternshipPurchased(msg.sender, internshipId);
    }

    function submitWork(uint256 internshipId, string calldata details) external {
        require(internships[internshipId].exists, "Internship does not exist");
        require(purchasedInternships[msg.sender][internshipId], "Internship not purchased by student");

        uint256 workId = internships[internshipId].nextWorkId;
        workLogs[internshipId][workId] = Work({
            internshipId: internshipId,
            student: msg.sender,
            details: details,
            verified: false,
            approvals: 0
        });

        emit WorkSubmitted(internshipId, workId, msg.sender);
        internships[internshipId].nextWorkId++;
    }

    function approveWork(uint256 internshipId, uint256 workId) external onlyApprover {
        require(internships[internshipId].exists, "Internship does not exist");
        require(workLogs[internshipId][workId].student != address(0), "Work does not exist");
        require(!hasApproved[internshipId][workId][msg.sender], "Already approved by this address");
        require(workLogs[internshipId][workId].student != msg.sender, "Cannot approve your own work");

        hasApproved[internshipId][workId][msg.sender] = true;
        workLogs[internshipId][workId].approvals++;

        emit WorkApproved(internshipId, workId, msg.sender);

        // If three unique addresses have approved, finalize the work
        if (workLogs[internshipId][workId].approvals >= 3 && !workLogs[internshipId][workId].verified) {
            workLogs[internshipId][workId].verified = true;
            approvedWorks[internshipId][workId] = true;
            emit WorkFinalized(internshipId, workId);
        }
    }

    function isWorkApproved(uint256 internshipId, uint256 workId) external view returns (bool) {
        return workLogs[internshipId][workId].verified;
    }

    // Retrieve all submitted works for a given internship
    function getSubmittedWorks(uint256 internshipId) external view returns (Work[] memory) {
        uint256 workCount = internships[internshipId].nextWorkId;
        Work[] memory works = new Work[](workCount);

        for (uint256 i = 0; i < workCount; i++) {
            works[i] = workLogs[internshipId][i];
        }

        return works;
    }

    // Retrieve only approved works for a given internship
    function getApprovedWorks(uint256 internshipId) external view returns (Work[] memory) {
        uint256 workCount = internships[internshipId].nextWorkId;
        uint256 approvedCount = 0;

        // Count the approved works
        for (uint256 i = 0; i < workCount; i++) {
            if (workLogs[internshipId][i].verified) {
                approvedCount++;
            }
        }

        // Populate array with only approved works
        Work[] memory approvedWorksList = new Work[](approvedCount);
        uint256 index = 0;

        for (uint256 i = 0; i < workCount; i++) {
            if (workLogs[internshipId][i].verified) {
                approvedWorksList[index] = workLogs[internshipId][i];
                index++;
            }
        }

        return approvedWorksList;
    }

    function getAllInternships() external view returns (Internship[] memory) {
        Internship[] memory allInternships = new Internship[](nextInternshipId);
        for (uint256 i = 0; i < nextInternshipId; i++) {
            allInternships[i] = internships[i];
        }
        return allInternships;
    }

    function getAllQuestions() external view returns (Question[] memory) {
        Question[] memory allQuestions = new Question[](nextQuestionId);
        for (uint256 i = 0; i < nextQuestionId; i++) {
            allQuestions[i] = questions[i];
        }
        return allQuestions;
    }
}
