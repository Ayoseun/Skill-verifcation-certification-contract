//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

contract Decentraskill {
    struct User {
        uint256 id;
        uint256 company_id;
        string name;
        address wallet_address;
        bool is_employed;
        bool is_manager;
        uint256 num_skill;
        uint256[] user_skills;
        uint256[] user_work_experience;
    }

    struct Certificate {
        string url;
        string issue_date;
        string valid_till;
        string name;
        uint256 id;
        string issuer;
    }

    struct Endorsement {
        uint256 endorser_id;
        string date;
        string comment;
    }

    struct Skill {
        uint256 id;
        string name;
        bool verified;
        uint256[] skill_certifications;
        uint256[] skill_endorsements;
    }

    struct Experience {
        string starting_date;
        string ending_date;
        string role;
        bool currently_working;
        uint256 company_id;
        bool is_approved;
    }

    struct Company {
        uint256 id; //company id which is the index of id in the global company array
        string name;
        address wallet_address;
        uint256[] current_employees;
        uint256[] previous_employees;
        uint256[] requested_employees;
    }

    Company[] public companies;
    User[] public employees;
    Certificate[] public certifications;
    Endorsement[] public endorsements;
    Skill[] public skills;
    Experience[] public experiences;
    /**
     * For the sign-in/signup process,
     * we plan to use the LinkedIn OAuth as the first layer of security
     * after which we shall map the email id of the user to their current wallet address in the smart contract.
     * So every time the user tries to sign in,
     * the user needs to sign in via the LinkedIn OAuth and also verify their wallet address.
     */
    // mapping of account's mail id with account's wallet address
    mapping(string => address) public email_to_address;
    // mapping of wallet address with account id
    mapping(address => uint256) public address_to_id;
    // mapping of wallet address with bool representing account status (Company/User)
    mapping(address => bool) public is_company;

    constructor() {
        /**
         * to remove the employee from the company's employee list
         * a dummy user profile in the constructor which can be reused after it has been initialized
         */
        User storage dummy_user = employees.push();
        dummy_user.name = "dummy";
        dummy_user.wallet_address = msg.sender;
        dummy_user.id = 0;
        dummy_user.user_skills = new uint256[](0);
        dummy_user.user_work_experience = new uint256[](0);
    }

    /**
     * For the functions used in the creation or updating of user data,
     *  only the linked user should be able to call them.
     *  To do this we create function modifiers that will allow us to reuse the necessary require statements in multiple functions,
     *  thus avoiding repetition of the same code.
     */
    modifier verifiedUser(uint256 user_id) {
        require(user_id == address_to_id[msg.sender]);
        _;
    }

    function sign_up(
        string calldata email,
        string calldata name,
        string calldata acc_type
    ) public {
        require(email_to_address[email] == address(0));
        email_to_address[email] == msg.sender;
        if (strcmp(acc_type, "user")) {
            User storage new_user = employees.push();
            new_user.name = name;
            new_user.id = employees.length - 1;
            new_user.wallet_address = msg.sender;
            address_to_id[msg.sender] = new_user.id;
            new_user.user_skills = new uint256[](0);
            new_user.user_work_experience = new uint256[](0);
        } else {
            //For company account
            Company storage new_company = companies.push(); // creates a new company and returns a reference to it
            new_company.name = name;
            new_company.id = companies.length - 1; // give account a unique company id
            new_company.wallet_address = msg.sender;
            new_company.current_employees = new uint256[](0);
            new_company.previous_employees = new uint256[](0);
            address_to_id[msg.sender] = new_company.id;
            is_company[msg.sender] = true;
        }
    }

    /**We use the view function modifier as
     * the function does not modify the state (any global variables)
     *  and only "views" them. */

    function login(string calldata email) public view returns (string memory) {
        // checking the function caller's wallet address from global map containing email address mapped to wallet address
        require(
            msg.sender == email_to_address[email],
            "error: incorrect wallet address used for signing in"
        );
        return (is_company[msg.sender]) ? "company" : "user"; // returns account type
    }

    /**We need to consider that a user might want to change the wallet address linked to their email/user id.
     * To do this, all the user needs to do is just provide the new wallet address
     *  while connected to their current/previous wallet address.
     */
    function update_wallet_address(
        string calldata email,
        address new_address
    ) public {
        require(
            email_to_address[email] == msg.sender,
            "error: function called from incorrect wallet address"
        );
        email_to_address[email] = new_address;
        uint256 id = address_to_id[msg.sender];
        address_to_id[msg.sender] = 0;
        address_to_id[new_address] = id;
    }

    /**
     * For adding an experience to a particular user,
     *  the add_experiance function will take the user's id,
     *  employment starting date, and ending date, and employer id i.e company id. 
     * This function creates a new object in the experiences global array
     *  and adds its id in the user's user_work_experience array and the company's requested_employees array.
     */

    function add_experience(
        uint256 user_id,
        string calldata starting_date,
        string calldata ending_date,
        uint256 company_id,
        string calldata role
    ) public verifiedUser(user_id) {
        Experience storage new_experience = experiences.push();
        new_experience.company_id = company_id;
        new_experience.currently_working = false;
        new_experience.is_approved = false;
        new_experience.starting_date = starting_date;
        new_experience.role = role;
        new_experience.ending_date = ending_date;
        employees[user_id].user_work_experience.push(experiences.length - 1);
        companies[company_id].requested_employees.push(experiences.length - 1);
    }

    /**
     * o approve a manager, the function approve_manager will take the employee id as input and
     * verify that the account calling the function has a "company" account type.
     *  It will then make sure that this employee id is present in the company's "current employees" list.
     *  If these checks pass, it will give that employee a manager tag by setting its is_manager boolean to true.
     */
    function approve_manager(uint256 employee_id) public {
        require(is_company[msg.sender], "error: sender not a company account");
        require(
            employees[employee_id].company_id == address_to_id[msg.sender],
            "error: user not of the same company"
        );
        require(
            !(employees[employee_id].is_manager),
            "error: user is already a manager"
        );
        employees[employee_id].is_manager = true;
    }

    function add_skill(
        uint256 userid,
        string calldata skill_name
    ) public verifiedUser(userid) {
        // the modifier that we created above
        Skill storage new_skill = skills.push();
        employees[userid].user_skills.push(skills.length - 1);
        new_skill.name = skill_name;
        new_skill.verified = false;
        new_skill.skill_certifications = new uint256[](0);
        new_skill.skill_endorsements = new uint256[](0);
    }

    function add_certification(
        uint256 user_id,
        string calldata url,
        string calldata issue_date,
        string calldata valid_till,
        string calldata name,
        string calldata issuer,
        uint256 linked_skill_id
    ) public verifiedUser(user_id) {
        Certificate storage new_certificate = certifications.push();
        new_certificate.url = url;
        new_certificate.issue_date = issue_date;
        new_certificate.valid_till = valid_till;
        new_certificate.name = name;
        new_certificate.id = certifications.length - 1;
        new_certificate.issuer = issuer;
        skills[linked_skill_id].skill_certifications.push(new_certificate.id);
    }

    function endorse_skill(
        uint256 user_id,
        uint256 skill_id,
        string calldata endorsing_date,
        string calldata comment
    ) public {
        Endorsement storage new_endorsemnt = endorsements.push();
        new_endorsemnt.endorser_id = address_to_id[msg.sender];
        new_endorsemnt.comment = comment;
        new_endorsemnt.date = endorsing_date;
        skills[skill_id].skill_endorsements.push(endorsements.length - 1);
        if (employees[address_to_id[msg.sender]].is_manager) {
            if (
                employees[address_to_id[msg.sender]].company_id ==
                employees[user_id].company_id
            ) {
                skills[skill_id].verified = true;
            }
        }
    }

    function memcmp(
        bytes memory a,
        bytes memory b
    ) internal pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b)); // Comapares the two hashes
    }

    function strcmp(
        string memory a,
        string memory b // string comparison function
    ) internal pure returns (bool) {
        return memcmp(bytes(a), bytes(b));
    }
}
