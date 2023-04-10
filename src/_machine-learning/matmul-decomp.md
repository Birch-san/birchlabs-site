---
layout: none
category: "Explorations"
within_category_ix: 30
title:  "Decomposing matrix multiplication"
---

<p>
  When it comes to representation of floating-point numbers: neural networks are <a href="https://cloud.google.com/blog/products/ai-machine-learning/bfloat16-the-secret-to-high-performance-on-cloud-tpus">far more sensitive</a> to the size of the exponent than the mantissa.
</p>
<p>
  There is an interesting property of the floating-point exponent: exponents can be multiplied by other exponents cheaply (integer addition).<br>This present an opportunity to compute the <em>exponent</em> portion of a matrix multiplication without using any floating-point hardware.
</p>
<p>
  I decomposed a matrix into its mantissa and exponent, multiplied its separate parts (the mantissae multiply via Hadamard product, the exponents multiply via addition), then recombined them to verify that it yields the same result as regular matrix multiplication.
</p>
<p>
  <em>This is just step 1 of a larger idea.</em><br>
  My hope is that we could <strong>discard the mantissa entirely</strong>, for parts of a neural network that primarily care about magnitude (e.g. computing attention probabilities in scaled dot product <a href="https://arxiv.org/abs/1706.03762">attention</a>).
</p>
<p>
  I think some extra tricks would be needed to make exponent-only attention probabilities differentiable. But if there's a way to do this, then it could drastically reduce the amount of silicon required for transformer training.
</p>
<p>
  If it cannot be differentiated: exponent-only attention probabilities could still be useful for optimizing <em>inference</em>.
</p>
<ul>
  <li><a href="https://twitter.com/Birchlabs/status/1616212662979022854">Twitter thread</a></li>
  <li><a href="https://gist.github.com/Birch-san/4f4945f219aa0118712a3f2fc619eba2">GitHub gist</a></li>
</ul>
