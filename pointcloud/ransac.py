import random

def sample(data, sample_size, accept_more=True, random_seed=None):
	random.seed(random_seed)
	p = sample_size * 1. / len(data)
	sample = []
	
	# this loop stops by probability -> 1
	while len(sample) < sample_size:
		sample = []
		for datum in data:
			if random.random() < p:
				sample.append(datum)
		if (accept_more and len(sample) >= sample_size) or len(sample) == sample_size:
			return sample

def run_ransac(data, estimate, is_inlier, sample_size, goal_inliers, max_iterations, 
stop_at_goal=True, random_seed=None):
	best_ic = 0
	best_model = None
	random.seed(random_seed)
	for i in xrange(max_iterations):
		s = sample(data, sample_size)
		m = estimate(s)
		ic = 0
		for j in xrange(len(data)):
			if is_inlier(m, data[j]):
				ic += 1
		
		#print s
		#print 'estimate:', m,
		#print '# inliers:', ic
		
		if ic > best_ic:
			best_ic = ic
			best_model = m
			if ic > goal_inliers and stop_at_goal:
				break
	#print 'took iterations:', i+1, 'best model:', best_model, 'explains:', best_ic
	return best_model, best_ic
