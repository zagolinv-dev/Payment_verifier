const express = require('express');
const bankVerify = require('./bankVerify');

const app = express();
app.use(express.json());
app.use('/', bankVerify);

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Bank verify server on :${PORT}`));
