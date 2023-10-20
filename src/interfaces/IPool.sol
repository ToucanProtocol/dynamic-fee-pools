interface IPool {
    function tokenBalances(address tco2) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
