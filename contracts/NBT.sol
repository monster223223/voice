pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

/**
 * @title NIX Bridge ERC20 token
 * @dev DAO for the NIX Platform Bridge on the Ethereum Protocol.
 *
 *      Each transaction that is not sent from the mapping of nonTaxedAddresses (initially owner and WETH/NBT uniswap pair)
 *      will be taxed at a rate of 1% paid out in NBT to the taxReceiveAddress.
 *
 *      Separate contracts will be launched for governance and liquidity incentives. NBT.sol powers the primary functionality
 *      of the NBT ERC20 Token.

 */
contract NBT is Initializable, ContextUpgradeSafe, IERC20, OwnableUpgradeSafe {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private constant INITIAL_SUPPLY =  60 * 10**3 * 10**18;

    /// @notice 1% (1/100) tax for every transaction
    uint16 public TAX_FRACTION;
    address public taxReceiveAddress;

    bool public isTaxEnabled;
    mapping(address => bool) public nonTaxedAddresses;

    event LogSetIsTaxEnabled(bool _isTaxEnabled);
    event LogSetAddressTax(address _address, bool ignoreTax);
    event LogChangeTaxFraction(uint16 _tax_fraction);
    event LogReceivedEther(uint256 _ether);
    event LogSetTaxReceiveAddress(address _taxReceiveAddress);

    function initialize() public initializer {
        _name = "NIX Bridge Token";
        _symbol = "NBT";
        _decimals = 18;
        __Context_init_unchained();
        __Ownable_init_unchained();

        isTaxEnabled = false;

        TAX_FRACTION = 100; // 1/100 = 1%

        _mint(_msgSender(), INITIAL_SUPPLY); // 60k tokens

        nonTaxedAddresses[_msgSender()] = true;
    }

    receive() external payable {
      emit LogReceivedEther(msg.value);
    }

    /**
     * @dev Enables/disabled the 1% tax on transactions
     *
     */
    function setIsTaxEnabled(bool _isTaxEnabled) external onlyOwner {
      isTaxEnabled = _isTaxEnabled;
      emit LogSetIsTaxEnabled(isTaxEnabled);
    }

    /**
     * @dev Sets the tax receive address
     *
     */
    function setTaxReceiveAddress(address _taxReceiveAddress) external onlyOwner {
      taxReceiveAddress = _taxReceiveAddress;
      emit LogSetTaxReceiveAddress(_taxReceiveAddress);
    }

    /**
     * @dev Add or remove address from the taxless whitelist.
     *
     * This is useful for adding new trading pairs in the future.
     */
    function setAddressTax(address _address, bool ignoreTax) external onlyOwner {
      nonTaxedAddresses[_address] = ignoreTax;
      emit LogSetAddressTax(_address, ignoreTax);
    }

    /**
     * @dev Set a new tax fraction.
     *
     */
    function setTaxFraction(uint16 _tax_fraction) external onlyOwner {
      TAX_FRACTION = _tax_fraction;
      emit LogChangeTaxFraction(_tax_fraction);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);
        //do not tax whitelisted addresses
        //do not tax if tax is disabled
        if(nonTaxedAddresses[sender] == true || isTaxEnabled == false){
          _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
          _balances[recipient] = _balances[recipient].add(amount);

          emit Transfer(sender, recipient, amount);
          return;
        }

        uint256 feeAmount = amount.div(TAX_FRACTION);
        uint256 newAmount = amount.sub(feeAmount);

        require(amount == feeAmount.add(newAmount), "ERC20: math is broken");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        // send amount minus the 1% fee
        _balances[recipient] = _balances[recipient].add(newAmount);
        // 1% NBT fee to taxReceiveAddress
        _balances[taxReceiveAddress] = _balances[taxReceiveAddress].add(feeAmount);

        emit Transfer(sender, recipient, newAmount);
        emit Transfer(sender, taxReceiveAddress, feeAmount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Public function for _burn()
     */
    function Burn(uint256 amount) external returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}
