## Must have 

- [ ] adherence to coding standard - proper segregation of code - what belongs where
- [ ] check for syntax issues or anti pattern
- [ ] if routes are created - proper handling of permissions etc - can there be a security flaw - can a non authorized role access a particular route which can cause data manipulation
- [ ] if models are created - changeset validations, unique constraints, foreign key constraints etc are in place or not
- [ ] logging of modification done on a model - *this only once we start implementing  - can ignore for now
- [ ] performance of queries - style of writing queries - whether proper indexing is used or not - ask for explain output of a query that you think will take time - this should be added to PR as comment only
are there unnecessary joins  - can the joins be avoided or can only be used based on condition
- [ ] Caching - is there some data that can be cached - we use Cachex plugin that can come handy - reference - https://github.com/brokernetworkapp/bn.apis/blob/master/lib/bn_apis/posts/posts.ex#L251

## Good to have

- [ ] Logical flaws in the feature architecture - are models defined properly in correct scopes or files structure etc
- [ ] Impact on other models - business use cases|
- [ ] Business impact of particular query of output
