require('torch')
require('model_tools')
require('nn')
require('rnn')
require('get_rand_batch')
require('cal_error')
require('optim')
-----------
--目前模型的维度还不一致
--
--1.读入数据
--增加日志打印
cmd = torch.CmdLine()
log = optim.Logger('results/train.log')
log:add{"1.开始读取数据"}

char_emds = read_words("data/input.train")
char_tensor = convert2tensors(char_emds)--类型的自动转换

word_emds = read_words("data/target.train")
word_tensor = convert2tensors(word_emds)--类型的自动转换

ds = {}
ds.size = count
ds.input = char_tensor
ds.output = word_tensor


--2.根据张量数据建立建立模型
--模型的初始参数
log:add{"2.开始建立模型"}--注意使用的是中括号
opt = {}
opt.learningRate = 0.01
opt.inputSize = 150
opt.hiddenSize = 50
opt.rho = 17 -- 最大的序列长度
opt.nIterations = 2 --迭代的次数设置
opt.batchSize = 10 -- 每批数据大小的设置
------------建立模型的过程
r = nn.Recurrent(
opt.hiddenSize, -- size of output 输出的维度大小
nn.Linear(opt.inputSize, opt.hiddenSize), -- input layer  nn.Identity()
nn.Linear(opt.hiddenSize, opt.hiddenSize), -- recurrent layer
nn.Sigmoid(), -- transfer function
opt.rho
)

rnn = nn.Sequential()
:add(r)
:add(nn.Linear(opt.hiddenSize, opt.hiddenSize))

criterion = nn.MSECriterion()
-- use Sequencer for better data handling
rnn = nn.Sequencer(rnn)
criterion = nn.SequencerCriterion(criterion)
print("Model :")
print(rnn)

--增加训练计时器
timer = torch.Timer()
cmd:text("3.开始训练模型")
---迭代的过程
for k = 1, opt.nIterations do
-- 1. 随机选择一批数据
local inputs,targets = genBatchData(ds.input,ds.output,opt.batchSize)

-- 2. 通过rnn输出向前进行传播
local outputs = rnn:forward(inputs) --是不是因为输入不是tesor?
local err = criterion:forward(outputs, targets)
print('Iter: ' .. k .. ' Err: ' .. err)
log:add{'Iter: ' .. k .. ' Err: ' .. err}
--testLogger:add{['Iter:'..k..' Err: '] = err}
-- 3. 通过rnn后向传播
rnn:zeroGradParameters()
local gradOutputs = criterion:backward(outputs, targets)
local gradInputs = rnn:backward(inputs, gradOutputs)
-- 4. 参数更新
rnn:updateParameters(opt.learningRate)
  if(k%200==0) then
    filename = "results/model"
    torch.save(filename..k,rnn)--序列化
  end
end
print('训练结束:'..timer:time().real..'秒')
log:add{'训练结束:'..timer:time().real..'秒'}

----基准数据的测试
cmd:text("4.开始测试结果")
allOutputs = rnn:forward(char_tensor)
--print("allOutput",allOutputs)
local err = getError(allOutputs, word_tensor)
print("生成模型和词向量的误差值",err)
log:add{"生成模型和词向量的误差值"..err}

----取均值和目标的误差值
avg_emds = read_words("data/avg.train")
avg_tensor = convert2tensors(avg_emds)--类型的自动转换
avgError = getError(word_tensor,avg_tensor)
print("直接取均值和词向量的误差值",avgError)
log:add{"直接取均值和词向量的误差值"..avgError}

--filename = "results/model"
--torch.save(filename,rnn)--序列化
--rnn = torch.load(filename)
--allOutputs2 = rnn:forward(char_tensor)
--print("allOutput",allOutputs2)

